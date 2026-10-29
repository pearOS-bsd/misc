/* Resizing a window from its edges and corners, live, as on the Mac: the window follows the pointer while the button is down (the application redraws at every step) and
 * is kept between its minimum and maximum size. GNUstep's own resize tracks the pointer in a nested loop from a small bar at the bottom of the title-bar decoration; the
 * window server here has no window manager, so the application does it, with plain events (no nested loop: a lost mouse-up cannot leave the window stuck, a button
 * release outside the application ends it too). A window that wants to be resizable although it has no resizable style mask (the Finder's) answers YES to -wsdIsResizable, and one that has its own draggable area (the Finder's toolbar) answers YES to -wsdWantsMoveAt: for the mouse-down event. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

enum { kLeft = 1, kRight = 2, kBottom = 4, kTop = 8 };
static const CGFloat kEdge = 5, kCorner = 14;

static IMP origSendEvent;
static NSWindow *gWin; static int gZone; static BOOL gMove; static NSPoint gStart; static NSRect gFrame;

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
static void Apply(NSPoint now)
{
	CGFloat dx = now.x - gStart.x, dy = now.y - gStart.y; NSRect f = gFrame;
	if (gMove) { f.origin = NSMakePoint(gFrame.origin.x + dx, gFrame.origin.y + dy); if (!NSEqualRects(f, [gWin frame])) [gWin setFrame: f display: NO]; return; }
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
	if (gWin) {
		if (t == NSLeftMouseDragged) { Apply([NSEvent mouseLocation]); return; }
		if (t == NSLeftMouseUp) { Apply([NSEvent mouseLocation]); gWin = nil; return; }
		if (t == NSMouseMoved || t == NSLeftMouseDown || t == NSRightMouseDown) gWin = nil;       /* the release was lost: a button that is not down ends it */
	}
	if (t == NSLeftMouseDown && [e window] && !gWin) {
		NSWindow *w = [e window]; int z = ZoneAt(w, [e locationInWindow]);
		if (z && Resizable(w)) { gWin = w; gZone = z; gMove = NO; gFrame = [w frame]; gStart = NSMakePoint(gFrame.origin.x + [e locationInWindow].x, gFrame.origin.y + [e locationInWindow].y); return; }
		if ([w respondsToSelector: @selector(wsdWantsMoveAt:)] && ((BOOL (*)(id, SEL, id))objc_msgSend)(w, @selector(wsdWantsMoveAt:), e)) { gWin = w; gZone = 0; gMove = YES; gFrame = [w frame]; gStart = NSMakePoint(gFrame.origin.x + [e locationInWindow].x, gFrame.origin.y + [e locationInWindow].y); return; }
	}
	((void (*)(id, SEL, id))origSendEvent)(self, _cmd, e);
}
@interface WsdResizeInit : NSObject @end
@implementation WsdResizeInit
+ (void)load { Method m = class_getInstanceMethod([NSApplication class], @selector(sendEvent:)); if (m) { origSendEvent = method_getImplementation(m); class_replaceMethod([NSApplication class], @selector(sendEvent:), (IMP)wsdResizeSend, method_getTypeEncoding(m)); } }
@end
