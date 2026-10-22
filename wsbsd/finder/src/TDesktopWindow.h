#import <AppKit/AppKit.h>
@interface TDesktopWindow : NSWindow { BOOL _desktopIsKeyWindow; }
- (instancetype)initWithScreen:(NSScreen *)screen;
- (BOOL)desktopIsKeyWindow;
@end
