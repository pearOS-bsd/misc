/* a window with SF Symbols drawn through NSImage (sizes, weights, buttons) */
#import <AppKit/AppKit.h>
@interface NSImageSymbolConfiguration : NSObject + (id)configurationWithPointSize:(CGFloat)p weight:(double)w; @end
@interface NSImage (S) + (NSImage *)imageWithSystemSymbolName:(NSString *)n accessibilityDescription:(NSString *)d; - (NSImage *)imageWithSymbolConfiguration:(id)c; @end
@interface Sheet : NSView @end
@implementation Sheet
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r
{
	[[NSColor whiteColor] set]; NSRectFill([self bounds]);
	NSArray *names = @[ @"star", @"heart.fill", @"gearshape", @"folder", @"trash", @"magnifyingglass", @"square.and.arrow.up", @"plus", @"xmark.circle.fill", @"wifi" ];
	double ws[] = { -0.8, 0, 0.4, 0.62 }; CGFloat sz[] = { 13, 20, 32 };
	for (int row = 0; row < 3; row++) for (NSUInteger i = 0; i < [names count]; i++) {
		NSImage *im = [[NSImage imageWithSystemSymbolName: names[i] accessibilityDescription: nil] imageWithSymbolConfiguration: [NSClassFromString(@"NSImageSymbolConfiguration") configurationWithPointSize: sz[row] weight: ws[(i % 4)]]];
		NSSize s = [im size]; [im drawInRect: NSMakeRect(20 + i * 50, 20 + row * 60, s.width, s.height) fromRect: NSZeroRect operation: NSCompositeSourceOver fraction: 1];
	}
}
@end
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 300, 540, 220) styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: NO];
		[w setContentView: [[Sheet alloc] initWithFrame: NSMakeRect(0, 0, 540, 220)]]; [w orderFront: nil];
		[NSTimer scheduledTimerWithTimeInterval: 10 target: NSApp selector: @selector(terminate:) userInfo: nil repeats: NO];
		[NSApp run];
	}
	return 0;
}
