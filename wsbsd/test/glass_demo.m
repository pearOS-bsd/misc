/* two windows: stripes behind, a window with an NSGlassEffectView (rounded, with a label) over it */
#import <AppKit/AppKit.h>
@interface Stripes : NSView @end
@implementation Stripes
- (void)drawRect:(NSRect)r { for (int i = 0; i < 40; i++) { [(i % 2 ? [NSColor redColor] : [NSColor blueColor]) set]; NSRectFill(NSMakeRect(i * 20, 0, 20, 400)); } }
@end
@interface NSObject (G) - (void)setContentView:(NSView *)v; - (void)setCornerRadius:(CGFloat)r; @end
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSWindow *a = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 300, 500, 300) styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: NO];
		[a setContentView: [[Stripes alloc] initWithFrame: NSMakeRect(0, 0, 500, 300)]]; [a orderFront: nil];
		NSWindow *b = [[NSWindow alloc] initWithContentRect: NSMakeRect(180, 340, 340, 160) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		NSView *host = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, 340, 160)];
		id g = [[NSClassFromString(@"NSGlassEffectView") alloc] initWithFrame: NSMakeRect(20, 20, 300, 120)];
		[g setCornerRadius: 32];
		NSTextField *t = [NSTextField labelWithString: @"Liquid Glass"]; [t setFont: [NSFont boldSystemFontOfSize: 28]]; [t setFrame: NSMakeRect(40, 40, 200, 40)];
		[g setContentView: t]; [host addSubview: g]; [b setContentView: host]; [b setLevel: NSFloatingWindowLevel]; [b orderFrontRegardless];
		[NSTimer scheduledTimerWithTimeInterval: 12 target: NSApp selector: @selector(terminate:) userInfo: nil repeats: NO];
		[NSApp run];
	}
	return 0;
}
