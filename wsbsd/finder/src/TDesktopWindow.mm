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
- (BOOL)canBecomeMainWindow { return NO; }
- (BOOL)desktopIsKeyWindow { return _desktopIsKeyWindow; }
- (void)becomeKeyWindow { _desktopIsKeyWindow = YES; [super becomeKeyWindow]; }
- (void)resignKeyWindow { _desktopIsKeyWindow = NO; [super resignKeyWindow]; }
@end
