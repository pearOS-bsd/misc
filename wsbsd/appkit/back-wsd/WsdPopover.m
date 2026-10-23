/* NSPopover. GNUstep's own class shows a dark grey panel at a wrong place and has no behaviours; this replaces its methods so that the Mac applications that use it (and the Finder: the Share and the
 * Add Tags popovers) get what the Mac gives: a panel in the window server's menu glass, the content inset by 13 pt (the accessibility tree of the real Finder's popovers: 266 x 342 around a 240 x 316
 * content), put against the rectangle in the edge asked for (above or below it with a 4 pt overlap, left or right of it), on the other side when the screen has no room, centred on it, kept on the
 * screen; a transient popover closes when it stops being the key window or on Escape; the notifications and the delegate calls of the real class. Not measured: the corner radius and the arrow. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import <GNUstepGUI/GSDisplayServer.h>

@interface GSDisplayServer (WsdPopover) - (void) wsdMenuGlass: (int)win : (int)width : (int)height; @end
static const CGFloat kInset = 13;
static char kPanelKey;

@interface WsdPopoverPanel : NSPanel { @public NSPopover *popover; } @end
@implementation WsdPopoverPanel
- (BOOL) canBecomeKeyWindow { return YES; }
- (BOOL) canBecomeMainWindow { return NO; }
- (void) resignKeyWindow { [super resignKeyWindow]; if (popover && [popover behavior] == NSPopoverBehaviorTransient) [popover close]; }
- (void) keyDown: (NSEvent *)e { if ([[e characters] isEqual: @"\x1b"] && [popover behavior] != NSPopoverBehaviorApplicationDefined) [popover performClose: nil]; else [super keyDown: e]; }
@end

static NSPanel *PanelOf(NSPopover *p) { return objc_getAssociatedObject(p, &kPanelKey); }
static void Post(NSPopover *p, NSString *name, SEL del)
{
	id d = [p delegate]; if (del && [d respondsToSelector: del]) ((void (*)(id, SEL, NSNotification *))objc_msgSend)(d, del, [NSNotification notificationWithName: name object: p]);
	[[NSNotificationCenter defaultCenter] postNotificationName: name object: p];
}
static void wsdPopoverShow(NSPopover *self, SEL _cmd, NSRect rect, NSView *view, NSRectEdge edge)
{
	if ([self isShown]) return; NSViewController *vc = [self contentViewController]; if ([vc respondsToSelector: @selector(loadView)]) [vc loadView]; NSView *content = [vc view]; if (!content || !view || ![view window]) return;
	NSSize cs = [self contentSize]; if (cs.width < 1 || cs.height < 1) cs = [content frame].size; NSSize ps = NSMakeSize(cs.width + 2 * kInset, cs.height + 2 * kInset);
	WsdPopoverPanel *panel = [[WsdPopoverPanel alloc] initWithContentRect: NSMakeRect(0, 0, ps.width, ps.height) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO]; panel->popover = self;
	[panel setOpaque: NO]; [panel setBackgroundColor: [NSColor clearColor]]; [panel setHasShadow: NO]; [panel setLevel: 101]; [panel setReleasedWhenClosed: NO]; [panel setExcludedFromWindowsMenu: YES]; [panel setAcceptsMouseMovedEvents: YES];
	NSView *box = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, ps.width, ps.height)]; [content setFrame: NSMakeRect(kInset, kInset, cs.width, cs.height)]; [box addSubview: content]; [panel setContentView: box];
	/* where: the rectangle in screen coordinates (origin bottom left) and the edge in the screen's terms (a flipped view counts its edges from the top) */
	NSRect r = [[view window] convertRectToScreen: [view convertRect: rect toView: nil]]; BOOL flipped = [view isFlipped]; NSRect sc = [[[view window] screen] frame]; if (NSIsEmptyRect(sc)) sc = [[NSScreen mainScreen] frame]; double top = NSMaxY(sc) - 30;
	NSInteger side = edge == NSMaxYEdge ? (flipped ? 3 : 2) : edge == NSMinYEdge ? (flipped ? 2 : 3) : edge == NSMaxXEdge ? 1 : 0;      /* 0 left, 1 right, 2 above, 3 below */
	NSRect f = NSMakeRect(0, 0, ps.width, ps.height);
	for (int tries = 0; tries < 2; tries++) {
		if (side == 2) { f.origin.y = NSMaxY(r) - 4; f.origin.x = NSMidX(r) - ps.width / 2; if (NSMaxY(f) > top && tries == 0) { side = 3; continue; } }
		else if (side == 3) { f.origin.y = NSMinY(r) + 4 - ps.height; f.origin.x = NSMidX(r) - ps.width / 2; if (f.origin.y < 0 && tries == 0) { side = 2; continue; } }
		else if (side == 1) { f.origin.x = NSMaxX(r) - 4; f.origin.y = NSMidY(r) - ps.height / 2; if (NSMaxX(f) > NSMaxX(sc) && tries == 0) { side = 0; continue; } }
		else { f.origin.x = NSMinX(r) + 4 - ps.width; f.origin.y = NSMidY(r) - ps.height / 2; if (f.origin.x < 0 && tries == 0) { side = 1; continue; } }
		break;
	}
	f.origin.x = MAX(NSMinX(sc), MIN(NSMaxX(sc) - ps.width, f.origin.x)); f.origin.y = MAX(NSMinY(sc), MIN(top - ps.height, f.origin.y));
	objc_setAssociatedObject(self, &kPanelKey, panel, OBJC_ASSOCIATION_RETAIN); [self setValue: @YES forKey: @"_shown"];
	Post(self, NSPopoverWillShowNotification, @selector(popoverWillShow:)); [panel setFrame: f display: YES]; [NSApp activateIgnoringOtherApps: YES]; [panel makeKeyAndOrderFront: nil];
	id srv = GSCurrentServer(); if ([srv respondsToSelector: @selector(wsdMenuGlass:::)]) [srv wsdMenuGlass: (int)[panel windowNumber] : (int)ps.width : (int)ps.height];
	Post(self, NSPopoverDidShowNotification, @selector(popoverDidShow:));
}
static void wsdPopoverClose(NSPopover *self, SEL _cmd)
{
	NSPanel *panel = PanelOf(self); if (!panel || ![self isShown]) return; Post(self, NSPopoverWillCloseNotification, @selector(popoverWillClose:));
	[self setValue: @NO forKey: @"_shown"]; ((WsdPopoverPanel *)panel)->popover = nil; [panel orderOut: nil]; [[self contentViewController].view removeFromSuperview]; objc_setAssociatedObject(self, &kPanelKey, nil, OBJC_ASSOCIATION_RETAIN);
	Post(self, NSPopoverDidCloseNotification, @selector(popoverDidClose:));
}
static void wsdPopoverPerformClose(NSPopover *self, SEL _cmd, id sender) { id d = [self delegate]; if ([d respondsToSelector: @selector(popoverShouldClose:)] && ![d popoverShouldClose: self]) return; [self close]; }
static BOOL wsdPopoverIsShown(NSPopover *self, SEL _cmd) { return PanelOf(self) != nil && [PanelOf(self) isVisible]; }

void WsdInstallPopover(void)
{
	static BOOL done; if (done) return; done = YES; Class c = [NSPopover class]; if (!c) return;
	class_replaceMethod(c, @selector(showRelativeToRect:ofView:preferredEdge:), (IMP)wsdPopoverShow, "v@:{CGRect={CGPoint=dd}{CGSize=dd}}@Q");
	class_replaceMethod(c, @selector(close), (IMP)wsdPopoverClose, "v@:"); class_replaceMethod(c, @selector(performClose:), (IMP)wsdPopoverPerformClose, "v@:@"); class_replaceMethod(c, @selector(isShown), (IMP)wsdPopoverIsShown, "c@:");
}
