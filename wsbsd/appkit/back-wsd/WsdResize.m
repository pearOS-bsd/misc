/* Window events the application handles for the whole system: resizing from the edges and corners, and the Command-Space shortcut (Spotlight).
 * Resizing a window from its edges and corners, live, as on the Mac: the window follows the pointer while the button is down (the application redraws at every step) and
 * is kept between its minimum and maximum size. GNUstep's own resize tracks the pointer in a nested loop from a small bar at the bottom of the title-bar decoration; the
 * window server here has no window manager, so the application does it, with plain events (no nested loop: a lost mouse-up cannot leave the window stuck, a button
 * release outside the application ends it too). A window that wants to be resizable although it has no resizable style mask (the Finder's) answers YES to -wsdIsResizable, and one that has its own draggable area (the Finder's toolbar) answers YES to -wsdWantsMoveAt: for the mouse-down event. */
#import <AppKit/AppKit.h>
#import <GNUstepGUI/GSDisplayServer.h>
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
	if (t == NSKeyDown && ([e modifierFlags] & NSCommandKeyMask) && ([e modifierFlags] & NSAlternateKeyMask) && [e keyCode] == 53) {       /* Command-Option-Escape: Force Quit Applications */
		[[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.forcequit.show" object: nil userInfo: nil deliverImmediately: YES]; return;
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


/* ---- the green button: full screen and the tiling popover that shows when the pointer rests on it (macOS 26) ----
 * Full screen here is the window over the whole area below the menu bar (30 pt) and its previous frame is kept in gSnapped's sibling; the same button (or Control-Command-F) leaves it. The popover lists what the Mac's does:
 * Enter / Exit Full Screen, Tile Window to Left of Screen, Tile Window to Right of Screen, Fill, Center (the geometry measured with Window > Move & Resize). */
static NSMutableDictionary *gFullSaved;
BOOL WsdIsFullscreen(NSWindow *w) { return gFullSaved && gFullSaved[@([w windowNumber])] != nil; }
void WsdToggleFullscreen(NSWindow *w)
{
	/* Full screen is a Space of its own, as on the Mac: the window covers the whole screen (the menu bar's strip too) in a space that only it lives in; the desktop, the other windows, the menu bar and the Dock are away until the pointer rests at the top / bottom edge (they come back over it) or the window leaves full screen (the same button, Control-Command-F), or closes. */
	if (!gFullSaved) gFullSaved = [[NSMutableDictionary alloc] init];
	NSNumber *k = @([w windowNumber]); id srv = GSCurrentServer(); BOOL has = [srv respondsToSelector: @selector(wsdSetActiveSpace:)];
	if (gFullSaved[k]) {
		if (has) { ((void (*)(id, SEL, unsigned))objc_msgSend)(srv, @selector(wsdSetActiveSpace:), 0); ((void (*)(id, SEL, int, unsigned))objc_msgSend)(srv, @selector(wsdSetWindowSpace::), [w windowNumber], 0); }
		[w setFrame: [gFullSaved[k] rectValue] display: YES]; [gFullSaved removeObjectForKey: k]; return;
	}
	gFullSaved[k] = [NSValue valueWithRect: [w frame]]; NSRect sc = [[NSScreen mainScreen] frame];
	if (has) {
		[w setFrame: sc display: YES];
		unsigned sid = ((unsigned (*)(id, SEL, int))objc_msgSend)(srv, @selector(wsdServerWindowID:), [w windowNumber]);
		((void (*)(id, SEL, int, unsigned))objc_msgSend)(srv, @selector(wsdSetWindowSpace::), [w windowNumber], sid); ((void (*)(id, SEL, unsigned))objc_msgSend)(srv, @selector(wsdSetActiveSpace:), sid);
	} else [w setFrame: NSMakeRect(sc.origin.x, sc.origin.y, sc.size.width, sc.size.height - kBarH) display: YES];
}
void WsdTileWindow(NSWindow *w, int where)       /* 0 left half, 1 right half, 2 fill, 3 center (a third smaller than the area) */
{
	NSRect v = VisibleArea(), f = v; if (!gSnapped) gSnapped = [[NSMutableDictionary alloc] init]; if (!gSnapped[@([w windowNumber])]) gSnapped[@([w windowNumber])] = [NSValue valueWithRect: [w frame]];
	if (where == 0) f.size.width /= 2; else if (where == 1) { f.size.width /= 2; f.origin.x += f.size.width; } else if (where == 4) { f.size.height /= 2; f.origin.y += f.size.height; } else if (where == 5) f.size.height /= 2; else if (where == 6) { f.size.width /= 2; f.size.height /= 2; f.origin.y += f.size.height; } else if (where == 3) { f = [w frame]; f.origin.x = NSMidX(v) - f.size.width / 2; f.origin.y = NSMidY(v) - f.size.height / 2; }
	[w setFrame: f display: YES];
}
/* the tiling popover of the green button, laid out from a capture of the real one (macOS 26, pixels at 1:1): a 270 wide panel; the headings "Move & Resize" and "Fill & Arrange" (11 pt bold, 40 % white) at x 17; under each a row of four window glyphs
 * (24 x 20, a 1.5 pt outline and the part of the window that is taken filled) on a pitch of 61 from x 42; a line at x 17 ... 254; "Full Screen" (13 pt, a window icon at x 23, a chevron at x 246); with a second display a last row "Move to
 * Built-in Display" (not shown on one display). The glyphs of arrangements that need several windows are dimmed (Left & Right, Left & Quarters). */
@interface WsdTilePanel : NSView { @public NSWindow *w; NSPopover *pop; } @end
@implementation WsdTilePanel
- (BOOL)isFlipped { return YES; } - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
static NSRect GlyphRect(int row, int col) { return NSMakeRect(42 + 61 * col - 12, row == 0 ? 39 : 118, 24, 20); }
static void DrawGlyph(NSRect r, int kind, BOOL dim)
{
	NSColor *line = [NSColor colorWithCalibratedWhite: 1 alpha: dim ? 0.40 : 0.92], *fill = [NSColor colorWithCalibratedWhite: 1 alpha: dim ? 0.40 : 0.90];
	NSBezierPath *o = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, 0.75, 0.75) xRadius: 3.5 yRadius: 3.5]; [o setLineWidth: 1.5]; [line setStroke]; [o stroke]; [fill setFill];
	NSRect in = NSInsetRect(r, 3.5, 3.5); CGFloat hw = in.size.width / 2 - 1, hh = in.size.height / 2 - 1;
	switch (kind) {
	case 0: NSRectFill(NSMakeRect(in.origin.x, in.origin.y, hw, in.size.height)); break;
	case 1: NSRectFill(NSMakeRect(NSMidX(in) + 1, in.origin.y, hw, in.size.height)); break;
	case 2: NSRectFill(NSMakeRect(in.origin.x, in.origin.y, in.size.width, hh)); break;
	case 3: NSRectFill(NSMakeRect(in.origin.x, NSMidY(in) + 1, in.size.width, hh)); break;
	case 4: NSRectFill(in); break;
	case 5: NSRectFill(NSMakeRect(in.origin.x, in.origin.y, hw, in.size.height)); [[NSColor colorWithCalibratedWhite: 1 alpha: 0.35] setFill]; NSRectFill(NSMakeRect(NSMidX(in) + 1, in.origin.y, hw, in.size.height)); break;
	case 6: NSRectFill(NSMakeRect(in.origin.x, in.origin.y, hw, in.size.height)); [[NSColor colorWithCalibratedWhite: 1 alpha: 0.35] setFill]; NSRectFill(NSMakeRect(NSMidX(in) + 1, in.origin.y, hw, hh)); NSRectFill(NSMakeRect(NSMidX(in) + 1, NSMidY(in) + 1, hw, hh)); break;
	default: for (int i = 0; i < 4; i++) NSRectFill(NSMakeRect(in.origin.x + (i % 2) * (hw + 2), in.origin.y + (i / 2) * (hh + 2), hw, hh));
	}
}
- (void)drawRect:(NSRect)r
{
	NSDictionary *hd = @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 11], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite: 1 alpha: 0.40] }, *td = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite: 1 alpha: 0.92] };
	[@"Move & Resize" drawAtPoint: NSMakePoint(17, 11) withAttributes: hd]; [@"Fill & Arrange" drawAtPoint: NSMakePoint(17, 90) withAttributes: hd];
	for (int i = 0; i < 4; i++) { DrawGlyph(GlyphRect(0, i), i, NO); DrawGlyph(GlyphRect(1, i), 4 + i, i == 1 || i == 2); }
	[[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] setFill]; NSRectFill(NSMakeRect(17, 76, 237, 1)); NSRectFill(NSMakeRect(17, 156, 237, 1));
	[@"Full Screen" drawAtPoint: NSMakePoint(38, 165) withAttributes: td];
	NSRect ir = NSMakeRect(22, 167, 12.5, 11); NSBezierPath *p = [NSBezierPath bezierPathWithRoundedRect: ir xRadius: 2 yRadius: 2]; [p setLineWidth: 1.2]; [[NSColor colorWithCalibratedWhite: 1 alpha: 0.85] setStroke]; [p stroke]; [[NSColor colorWithCalibratedWhite: 1 alpha: 0.85] setFill]; NSRectFill(NSMakeRect(NSMidX(ir) - 0.5, ir.origin.y + 1, 1, ir.size.height - 2));
	NSBezierPath *ch = [NSBezierPath bezierPath]; [ch setLineWidth: 1.8]; [ch setLineCapStyle: NSRoundLineCapStyle]; [ch setLineJoinStyle: NSRoundLineJoinStyle]; [ch moveToPoint: NSMakePoint(243, 168)]; [ch lineToPoint: NSMakePoint(248, 173)]; [ch lineToPoint: NSMakePoint(243, 178)]; [ch stroke];
}
- (void)mouseDown:(NSEvent *)e
{
	NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; int hit = -1; static const int row0[4] = { 0, 1, 4, 5 }, row1[4] = { 2, -1, -1, 6 };       /* WsdTileWindow: 0 left, 1 right, 4 top, 5 bottom, 2 fill, 6 top-left quarter */
	for (int i = 0; i < 4; i++) { if (NSPointInRect(p, NSInsetRect(GlyphRect(0, i), -14, -10))) hit = row0[i]; if (NSPointInRect(p, NSInsetRect(GlyphRect(1, i), -14, -10))) hit = row1[i]; }
	if (hit < 0 && p.y > 160 && p.y < 188) hit = 10;
	if (hit < 0) return; [pop close]; if (hit == 10) WsdToggleFullscreen(w); else WsdTileWindow(w, hit);
}
@end
void WsdShowTilePopover(NSWindow *w, NSRect buttonInWindow)
{
	static NSPopover *pop; if (pop && [pop isShown]) return;
	WsdTilePanel *v = [[WsdTilePanel alloc] initWithFrame: NSMakeRect(0, 0, 270, 190)]; v->w = w;
	NSViewController *vc = [[NSViewController alloc] init]; [vc setView: v]; pop = [[NSPopover alloc] init]; [pop setContentViewController: vc]; [pop setBehavior: NSPopoverBehaviorTransient]; v->pop = pop;
	[pop showRelativeToRect: buttonInWindow ofView: [[w contentView] superview] preferredEdge: NSMinYEdge];
	NSWindow *pw = [v window]; if (pw) {       /* on the Mac the panel starts 27 left of the button's centre and hangs 12 below the button (the arrow points at the button) */
		NSRect br = [w convertRectToScreen: buttonInWindow]; NSRect f = [pw frame]; f.origin.x = NSMidX(br) - 27; f.origin.y = NSMinY(br) - 12 - f.size.height; [pw setFrame: f display: YES]; }
}

/* GNUstep's autodisplay (+[NSWindow _handleAutodisplay:]) calls every window's -_handleAutodisplay and schedules itself again only at the end: when one window raises while it is drawn (the menu bar's panel did, at the start of every program: "NSRunLoop ignoring exception ... _handleAutodisplay:") the loop is never scheduled again and no window is redrawn by -setNeedsDisplay: any more (held window buttons did not stretch, hover did not follow). Every window's step is guarded: the exception is logged (five times) and the window's flush, disabled for the drawing, is enabled again. */
@interface NSWindow (WsdAutodisplayGuard) @end
@implementation NSWindow (WsdAutodisplayGuard)
+ (void) load
{
	Method a = class_getInstanceMethod(self, @selector(_handleAutodisplay)), b = class_getInstanceMethod(self, @selector(wsdGuardedAutodisplay));
	if (a && b) method_exchangeImplementations(a, b);
}
- (void) wsdGuardedAutodisplay       /* after the exchange: this is the original -_handleAutodisplay, and the original name runs the guard */
{
	@try { [self wsdGuardedAutodisplay]; }
	@catch (NSException *e) {
		static int n; if (n++ < 5) NSLog(@"wsd: drawing %@ raised %@: %@", [self class], [e name], [e reason]);
		@try { [self enableFlushWindow]; [self flushWindowIfNeeded]; } @catch (NSException *e2) {}
	}
}
@end

/* "Reopen": the Dock asks a running application that has no window to open one (a click on its tile, as on the Mac; closing the last window leaves the process running). The application's delegate is asked first (applicationShouldHandleReopen:hasVisibleWindows:); if it has no opinion or says yes, the first of the usual "new window" actions that something answers is sent. */
@interface WsdReopen : NSObject @end
@implementation WsdReopen
+ (void)load
{
	[[NSNotificationCenter defaultCenter] addObserverForName: NSApplicationDidFinishLaunchingNotification object: nil queue: nil usingBlock: ^(NSNotification *n) {
		[[NSDistributedNotificationCenter defaultCenter] addObserverForName: @"com.wsbsd.dock.reopen" object: nil queue: nil usingBlock: ^(NSNotification *m) {
			if ([[m userInfo][@"pid"] intValue] != (int)getpid()) return; [NSApp activateIgnoringOtherApps: YES];
			BOOL vis = NO; for (NSWindow *w in [NSApp windows]) if ([w isVisible] && [w level] == NSNormalWindowLevel && ![w isKindOfClass: NSClassFromString(@"NSMenuPanel")]) vis = YES;
			for (NSWindow *w in [NSApp windows]) if ([w isMiniaturized]) [w deminiaturize: nil];
			id d = [NSApp delegate]; BOOL go = YES; if ([d respondsToSelector: @selector(applicationShouldHandleReopen:hasVisibleWindows:)]) go = [d applicationShouldHandleReopen: NSApp hasVisibleWindows: vis];
			if (go && !vis) for (NSString *a in @[ @"newDocument:", @"newWindow:", @"newTerminalWindow:", @"newBrowserWindow:" ]) if ([NSApp sendAction: NSSelectorFromString(a) to: nil from: nil]) break;
		}];
	}];
}
@end

/* GNUstep's NSDiacriticInsensitiveSearch finds nothing at all (a search with it never matched, so Spotlight and the Finder search looked case sensitive): the strings are folded here instead (decomposed, the combining marks dropped) and searched without the flag.
 * NSString and GSImmutableString (the class of the literals) both implement -rangeOfString:options:range: and both are wrapped. */
static IMP gOrigRange[2], gOrigRangeL[2];
static NSString *WsdFold(NSString *x) { NSString *d = [x decomposedStringWithCanonicalMapping]; NSMutableString *o = [NSMutableString stringWithCapacity: [d length]]; for (NSUInteger i = 0; i < [d length]; i++) { unichar c = [d characterAtIndex: i]; if (c >= 0x0300 && c <= 0x036F) continue; [o appendFormat: @"%C", c]; } return o; }
static NSRange WsdRangeOf(id self, SEL _cmd, NSString *s, NSUInteger mask, NSRange r)
{
	if (mask & NSDiacriticInsensitiveSearch) {
		NSString *hay = WsdFold([self substringWithRange: r]), *nd = WsdFold(s); NSRange f = [hay rangeOfString: nd options: (mask & ~NSDiacriticInsensitiveSearch) range: NSMakeRange(0, [hay length])];
		if (f.location != NSNotFound) f.location += r.location; return f;
	}
	Class gs = NSClassFromString(@"GSImmutableString"); IMP o = (gs && [self isKindOfClass: gs] && gOrigRange[1]) ? gOrigRange[1] : gOrigRange[0];
	return ((NSRange (*)(id, SEL, NSString *, NSUInteger, NSRange))o)(self, _cmd, s, mask, r);
}
static NSRange WsdRangeOfL(id self, SEL _cmd, NSString *s, NSUInteger mask, NSRange r, id loc)
{
	if (mask & NSDiacriticInsensitiveSearch) return WsdRangeOf(self, @selector(rangeOfString:options:range:), s, mask, r);
	Class gs = NSClassFromString(@"GSImmutableString"); IMP o = (gs && [self isKindOfClass: gs] && gOrigRangeL[1]) ? gOrigRangeL[1] : gOrigRangeL[0];
	return ((NSRange (*)(id, SEL, NSString *, NSUInteger, NSRange, id))o)(self, _cmd, s, mask, r, loc);
}
@interface WsdDiacriticFix : NSObject @end
@implementation WsdDiacriticFix
+ (void)load
{
	SEL sel = @selector(rangeOfString:options:range:); const char *names[2] = { "NSString", "GSImmutableString" };
	for (int i = 0; i < 2; i++) { Class c = objc_getClass(names[i]); if (!c) continue; Method m = class_getInstanceMethod(c, sel); if (!m) continue; gOrigRange[i] = method_setImplementation(m, (IMP)WsdRangeOf); if (i == 1 && gOrigRange[1] == gOrigRange[0]) gOrigRange[1] = NULL;
		Method ml = class_getInstanceMethod(c, @selector(rangeOfString:options:range:locale:)); if (ml) { gOrigRangeL[i] = method_setImplementation(ml, (IMP)WsdRangeOfL); if (i == 1 && gOrigRangeL[1] == gOrigRangeL[0]) gOrigRangeL[1] = NULL; } }
}
@end

/* The pop-up list of a combo box (GSComboWindow with a GSComboBoxTableView): the row under the pointer is blue with white text, as on the Mac, without the pointer having to be pressed; the rows are drawn with an inset and the (empty) scroller is left out when everything fits. The row is found by a timer that looks at the pointer while such a window is on screen. */
static NSInteger gComboHover = -1;
static NSTimer *gComboTimer;
@interface WsdComboFix : NSObject @end
static void WsdComboDrawRow(id self, SEL _cmd, NSInteger row, NSRect clip)
{
	if (!gComboTimer) { gComboTimer = [NSTimer timerWithTimeInterval: 0.04 target: [WsdComboFix class] selector: @selector(poll:) userInfo: nil repeats: YES]; for (NSString *m in @[ NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode ]) [[NSRunLoop currentRunLoop] addTimer: gComboTimer forMode: m]; }
	NSRect r = [self rectOfRow: row]; BOOL hot = [self isRowSelected: row];
	if (hot) { [[NSColor colorWithCalibratedRed: 0.04 green: 0.52 blue: 1.0 alpha: 1] setFill]; [[NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, 4, 1) xRadius: 5 yRadius: 5] fill]; }
	id v = [[self dataSource] tableView: self objectValueForTableColumn: [[self tableColumns] firstObject] row: row]; NSString *t = [v description] ?: @"";
	NSDictionary *at = @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: hot ? [NSColor whiteColor] : [NSColor controlTextColor] }; NSSize sz = [t sizeWithAttributes: at];
	[t drawAtPoint: NSMakePoint(r.origin.x + 12, r.origin.y + (r.size.height - sz.height) / 2) withAttributes: at];
}
static void WsdComboNoHighlight(id self, SEL _cmd, NSRect clip) {}
@implementation WsdComboFix
+ (void)load
{
	Class tc = objc_getClass("GSComboBoxTableView"); if (!tc) return;
	class_replaceMethod(tc, @selector(drawRow:clipRect:), (IMP)WsdComboDrawRow, "v@:{_NSRect={_NSPoint=ff}{_NSSize=ff}}"); class_replaceMethod(tc, @selector(highlightSelectionInClipRect:), (IMP)WsdComboNoHighlight, "v@:{_NSRect={_NSPoint=ff}{_NSSize=ff}}");
}
+ (void)poll:(NSTimer *)t
{
	NSWindow *cw = nil; Class wc = objc_getClass("GSComboWindow"); if (!wc) return; for (NSWindow *w in [NSApp windows]) if ([w isKindOfClass: wc] && [w isVisible]) { cw = w; break; }
	static int dbg; if (getenv("WSD_COMBO_DEBUG") && dbg++ < 5) NSLog(@"combo poll: window %@ windows %lu", cw, (unsigned long)[[NSApp windows] count]);
	if (!cw) { gComboHover = -1; return; }
	Ivar iv = class_getInstanceVariable(wc, "_tableView"); NSTableView *tv = iv ? object_getIvar(cw, iv) : nil; if (!tv) return;
	NSScrollView *sv = [tv enclosingScrollView]; if (sv && [sv hasVerticalScroller] && [tv numberOfRows] <= 7) { [sv setHasVerticalScroller: NO]; [sv tile]; [tv sizeLastColumnToFit]; [cw display]; }
	NSPoint p = [tv convertPoint: [cw convertScreenToBase: [NSEvent mouseLocation]] fromView: nil]; NSInteger row = NSPointInRect(p, [tv bounds]) ? [tv rowAtPoint: p] : -1;
	static NSInteger lastLogged = -99; if (getenv("WSD_COMBO_DEBUG") && row != lastLogged && (lastLogged = row) != -99) NSLog(@"combo hover: p=%@ bounds=%@ row=%ld mouse=%@ tvwin=%@", NSStringFromPoint(p), NSStringFromRect([tv bounds]), (long)row, NSStringFromPoint([NSEvent mouseLocation]), NSStringFromRect([cw frame]));
	if (row != gComboHover) { gComboHover = row; if (row >= 0) [tv selectRowIndexes: [NSIndexSet indexSetWithIndex: (NSUInteger)row] byExtendingSelection: NO]; else [tv deselectAll: nil]; [tv setNeedsDisplay: YES]; [tv displayIfNeeded]; while (![cw isFlushWindowDisabled] == NO) [cw enableFlushWindow]; [cw flushWindow]; }
}
@end
