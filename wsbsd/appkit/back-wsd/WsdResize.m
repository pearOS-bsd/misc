/* Window events the application handles for the whole system: resizing from the edges and corners, and the Command-Space shortcut (Spotlight).
 * Resizing a window from its edges and corners, live, as on the Mac: the window follows the pointer while the button is down (the application redraws at every step) and
 * is kept between its minimum and maximum size. GNUstep's own resize tracks the pointer in a nested loop from a small bar at the bottom of the title-bar decoration; the
 * window server here has no window manager, so the application does it, with plain events (no nested loop: a lost mouse-up cannot leave the window stuck, a button
 * release outside the application ends it too). A window that wants to be resizable although it has no resizable style mask (the Finder's) answers YES to -wsdIsResizable, and one that has its own draggable area (the Finder's toolbar) answers YES to -wsdWantsMoveAt: for the mouse-down event. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

enum { kLeft = 1, kRight = 2, kBottom = 4, kTop = 8 };
static const CGFloat kEdge = 5, kCorner = 14;

static IMP origSendEvent;
static NSWindow *gWin; static int gZone; static BOOL gMove; static NSPoint gGrab;       /* gGrab: where in the window the pointer took hold (its share of the width) */
static NSMutableDictionary *gSnapped;       /* window number -> the frame it had before it was tiled */ static NSPoint gStart; static NSRect gFrame;

static BOOL Resizable(NSWindow *w)
{
	if ([w isSheet] || [w level] > NSFloatingWindowLevel) return NO;
	if ([w respondsToSelector: @selector(wsdIsResizable)]) return ((BOOL (*)(id, SEL))objc_msgSend)(w, @selector(wsdIsResizable));
	return ([w styleMask] & NSResizableWindowMask) != 0 && ![w isKindOfClass: NSClassFromString(@"NSMenuPanel")];
}
/* which edges the point (window coordinates, origin bottom left) is on */
static int ZoneAt(NSWindow *w, NSPoint p)
{
	NSSize s = [w frame].size; int z = 0;
	BOOL nearL = p.x < kCorner, nearR = p.x > s.width - kCorner, nearB = p.y < kCorner, nearT = p.y > s.height - kCorner;
	if (p.x < kEdge) z |= kLeft; else if (p.x > s.width - kEdge) z |= kRight;
	if (p.y < kEdge) z |= kBottom; else if (p.y > s.height - kEdge) z |= kTop;
	if (z & (kLeft | kRight)) { if (nearB) z |= kBottom; else if (nearT) z |= kTop; }       /* on a side near a corner: the corner */
	if (z & (kBottom | kTop)) { if (nearL) z |= kLeft; else if (nearR) z |= kRight; }
	return z;
}
static NSSize FrameSizeFor(NSWindow *w, NSSize content) { return [w frameRectForContentRect: NSMakeRect(0, 0, content.width, content.height)].size; }
/* Window tiling, measured on the Mac with Window > Move & Resize on a 3440 x 1440 screen: the tiles fill the area below the menu bar (30) and above the Dock (84) edge to edge with no margins: Left / Right = half the width, Top / Bottom = half the height, quarters at the corners, a drag to the top edge fills it. */
static const CGFloat kBarH = 30, kDockH = 84;
static NSRect VisibleArea(void) { NSRect sc = [[NSScreen mainScreen] frame]; return NSMakeRect(sc.origin.x, sc.origin.y + kDockH, sc.size.width, sc.size.height - kBarH - kDockH); }
/* the tile the pointer (screen coordinates, origin bottom left) asks for by touching an edge of the screen, or an empty rect */
static NSRect TileFor(NSPoint m)
{
	NSRect sc = [[NSScreen mainScreen] frame], v = VisibleArea(); CGFloat hw = v.size.width / 2, hh = v.size.height / 2; const CGFloat edge = 1, corner = 110;
	BOOL L = m.x <= NSMinX(sc) + edge, R = m.x >= NSMaxX(sc) - edge, T = m.y >= NSMaxY(sc) - edge, B = m.y <= NSMinY(sc) + edge;
	BOOL nearTop = m.y >= NSMaxY(sc) - corner, nearBot = m.y <= NSMinY(sc) + corner + kDockH;
	if ((L || R) && nearTop) return NSMakeRect(L ? v.origin.x : v.origin.x + hw, v.origin.y + hh, hw, hh);
	if ((L || R) && nearBot) return NSMakeRect(L ? v.origin.x : v.origin.x + hw, v.origin.y, hw, hh);
	if (L) return NSMakeRect(v.origin.x, v.origin.y, hw, v.size.height);
	if (R) return NSMakeRect(v.origin.x + hw, v.origin.y, hw, v.size.height);
	if (T) return v;
	(void)B; return NSZeroRect;
}
static NSWindow *gPreview; static NSRect gPreviewRect;
static void ShowPreview(NSRect r)
{
	if (NSIsEmptyRect(r)) { [gPreview orderOut: nil]; gPreviewRect = NSZeroRect; return; }
	if (NSEqualRects(r, gPreviewRect)) return; gPreviewRect = r;
	if (!gPreview) {
		gPreview = [[NSWindow alloc] initWithContentRect: r styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO]; [gPreview setOpaque: NO]; [gPreview setBackgroundColor: [NSColor clearColor]]; [gPreview setHasShadow: NO]; [gPreview setIgnoresMouseEvents: YES]; [gPreview setReleasedWhenClosed: NO]; [gPreview setLevel: NSFloatingWindowLevel];
		NSVisualEffectView *ev = [[NSVisualEffectView alloc] initWithFrame: NSMakeRect(0, 0, r.size.width, r.size.height)]; [ev setMaterial: NSVisualEffectMaterialPopover]; [ev setBlendingMode: NSVisualEffectBlendingModeBehindWindow]; [ev setState: NSVisualEffectStateActive]; [ev setAutoresizingMask: NSViewWidthSizable | NSViewHeightSizable]; [gPreview setContentView: ev];
	}
	[gPreview setFrame: r display: YES]; [(id)NSClassFromString(@"WsdFinderSupport") roundWindow: gPreview radius: 12]; [gPreview orderFront: nil];
}
static void EndMove(BOOL snap)
{
	NSRect t = snap ? TileFor([NSEvent mouseLocation]) : NSZeroRect; ShowPreview(NSZeroRect);
	if (!NSIsEmptyRect(t) && gWin) { if (!gSnapped) gSnapped = [[NSMutableDictionary alloc] init];       /* not ARC: kept */ if (!gSnapped[@([gWin windowNumber])]) gSnapped[@([gWin windowNumber])] = [NSValue valueWithRect: gFrame]; [gWin setFrame: t display: YES]; }
}
static void Apply(NSPoint now)
{
	CGFloat dx = now.x - gStart.x, dy = now.y - gStart.y; NSRect f = gFrame;
	if (gMove) {
		NSValue *pre = gSnapped[@([gWin windowNumber])];
		if (pre && (fabs(dx) > 3 || fabs(dy) > 3)) {       /* a tiled window taken by its title bar gets its old size back, under the pointer */
			NSRect o = [pre rectValue]; [gSnapped removeObjectForKey: @([gWin windowNumber])]; CGFloat share = (gStart.x - gFrame.origin.x) / MAX(1, gFrame.size.width);
			gFrame = NSMakeRect(gStart.x - share * o.size.width, NSMaxY(gFrame) - o.size.height, o.size.width, o.size.height); dx = now.x - gStart.x; dy = now.y - gStart.y;
		}
		f = gFrame; f.origin = NSMakePoint(gFrame.origin.x + dx, gFrame.origin.y + dy);
		if (NSMaxY(f) > NSMaxY([[NSScreen mainScreen] frame]) - kBarH) f.origin.y = NSMaxY([[NSScreen mainScreen] frame]) - kBarH - f.size.height;       /* the title bar stays below the menu bar */
		if (!NSEqualRects(f, [gWin frame])) [gWin setFrame: f display: NO]; ShowPreview(TileFor(now)); return; }
	NSSize mn = FrameSizeFor(gWin, [gWin minSize]), mx = FrameSizeFor(gWin, [gWin maxSize]);
	if (mn.width < 40) mn.width = 40; if (mn.height < 40) mn.height = 40;
	if (gZone & kRight) f.size.width = gFrame.size.width + dx; if (gZone & kLeft) f.size.width = gFrame.size.width - dx;
	if (gZone & kTop) f.size.height = gFrame.size.height + dy; if (gZone & kBottom) f.size.height = gFrame.size.height - dy;
	f.size.width = MAX(mn.width, MIN(mx.width, f.size.width)); f.size.height = MAX(mn.height, MIN(mx.height, f.size.height));
	if (gZone & kLeft) f.origin.x = NSMaxX(gFrame) - f.size.width; if (gZone & kBottom) f.origin.y = NSMaxY(gFrame) - f.size.height;
	if (!NSEqualRects(f, [gWin frame])) [gWin setFrame: f display: YES];
}

static void wsdResizeSend(NSApplication *self, SEL _cmd, NSEvent *e)
{
	NSEventType t = [e type];
	if (t == NSKeyDown && ([e modifierFlags] & NSCommandKeyMask) && !([e modifierFlags] & (NSShiftKeyMask | NSAlternateKeyMask | NSControlKeyMask)) && [[e charactersIgnoringModifiers] isEqual: @" "]) {       /* Command-Space: Spotlight, wherever the keyboard is */
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.spotlight.toggle" object: nil userInfo: nil deliverImmediately: YES]; return;
	}
	if (gWin) {
		if (t == NSLeftMouseDragged) { Apply([NSEvent mouseLocation]); return; }
		if (t == NSLeftMouseUp) { Apply([NSEvent mouseLocation]); if (gMove) EndMove(YES); gWin = nil; return; }
		if (t == NSMouseMoved || t == NSLeftMouseDown || t == NSRightMouseDown) { if (gMove) EndMove(NO); gWin = nil; }       /* the release was lost: a button that is not down ends it */
	}
	if (t == NSLeftMouseDown && [e window] && !gWin) {
		NSWindow *w = [e window]; int z = ZoneAt(w, [e locationInWindow]);
		if (z && Resizable(w)) { gWin = w; gZone = z; gMove = NO; gFrame = [w frame]; gStart = NSMakePoint(gFrame.origin.x + [e locationInWindow].x, gFrame.origin.y + [e locationInWindow].y); return; }
		if (!gWin && ([w styleMask] & NSTitledWindowMask) && ![w isSheet] && [e clickCount] < 2 && [w level] <= NSFloatingWindowLevel && ![w isKindOfClass: NSClassFromString(@"NSMenuPanel")]) {       /* the title bar of an ordinary window: moved by the application, tiled at the screen edges */
			NSPoint lp = [e locationInWindow]; CGFloat tb = [w frame].size.height - [w contentRectForFrameRect: [w frame]].size.height;
			if (tb > 8 && lp.y > [w frame].size.height - tb && lp.x > 80 && lp.x < [w frame].size.width - 6) { gWin = w; gZone = 0; gMove = YES; gFrame = [w frame]; gStart = NSMakePoint(gFrame.origin.x + lp.x, gFrame.origin.y + lp.y); return; }
		}
		if ([w respondsToSelector: @selector(wsdWantsMoveAt:)] && ((BOOL (*)(id, SEL, id))objc_msgSend)(w, @selector(wsdWantsMoveAt:), e)) { gWin = w; gZone = 0; gMove = YES; gFrame = [w frame]; gStart = NSMakePoint(gFrame.origin.x + [e locationInWindow].x, gFrame.origin.y + [e locationInWindow].y); return; }
	}
	((void (*)(id, SEL, id))origSendEvent)(self, _cmd, e);
}
@interface WsdResizeInit : NSObject @end
@implementation WsdResizeInit
+ (void)load { Method m = class_getInstanceMethod([NSApplication class], @selector(sendEvent:)); if (m) { origSendEvent = method_getImplementation(m); class_replaceMethod([NSApplication class], @selector(sendEvent:), (IMP)wsdResizeSend, method_getTypeEncoding(m)); } }
@end
