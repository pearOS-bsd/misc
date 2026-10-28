/* TDesktopWindow: the window that carries the desktop icons, one per screen, at the desktop icon window level (-2147483603 on the Mac, measured with CGWindowListCopyWindowInfo on the reference Mac).
 * Decompiled: -[TDesktopWindow canBecomeKeyWindow] returns YES, -desktopIsKeyWindow reads an instance variable. */
#import "TDesktopWindow.h"

@implementation TDesktopWindow
- (instancetype)initWithScreen:(NSScreen *)screen
{
	NSRect f = [screen frame];
	if ((self = [super initWithContentRect: f styleMask: NSWindowStyleMaskBorderless backing: NSBackingStoreBuffered defer: NO screen: screen])) {
		[self setLevel: getenv("FINDER_DESKTOP_LEVEL") ? (NSInteger)atoll(getenv("FINDER_DESKTOP_LEVEL")) : (NSInteger)-2147483603]; [self setOpaque: NO]; [self setBackgroundColor: [NSColor clearColor]]; [self setHasShadow: NO]; [self setReleasedWhenClosed: NO];
		[self setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary | NSWindowCollectionBehaviorIgnoresCycle]; [self setTitle: @"Desktop"];
	}
	return self;
}
- (BOOL)canBecomeKeyWindow { return YES; }
/* a click on the desktop makes the Finder the active application (its menu bar comes back, the one of the application that was in front goes) and gives the desktop key focus at the window server, which does not do it for a window below the normal level */
- (void)sendEvent:(NSEvent *)e { if ([e type] == NSLeftMouseDown || [e type] == NSRightMouseDown) { [NSApp activateIgnoringOtherApps: YES]; if (![self isKeyWindow]) [self makeKeyWindow]; Class sp = NSClassFromString(@"WsdFinderSupport"); if ([sp respondsToSelector: @selector(setKeyWindow:)]) [sp performSelector: @selector(setKeyWindow:) withObject: self]; } [super sendEvent: e]; }
- (BOOL)canBecomeMainWindow { return NO; }
- (BOOL)desktopIsKeyWindow { return _desktopIsKeyWindow; }
- (void)becomeKeyWindow { _desktopIsKeyWindow = YES; [super becomeKeyWindow]; }
- (void)resignKeyWindow { _desktopIsKeyWindow = NO; [super resignKeyWindow]; }
@end
