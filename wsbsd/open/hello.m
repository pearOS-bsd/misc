/* The first AppKit program on the open AppKit: a window with a view that draws. Built with the headers of appkit/decompiled/src. */
#import "NSApplication.h"
#import "NSWindow.h"
#import "NSView.h"
#import "NSColor.h"
#import "NSFont.h"

@interface V : NSView @end
@implementation V
- (void)drawRect:(CGRect)r { [[NSColor yellowColor] setFill]; NSRectFill([self bounds]); [[NSColor redColor] setFill]; NSRectFill(CGRectMake(20, 20, 120, 60));
  [@"open: AppKit on wsd" drawAtPoint:CGPointMake(20, 200) withAttributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:28], NSForegroundColorAttributeName: [NSColor blackColor] }]; }
@end
int main(void) { @autoreleasepool {
  NSApplication *a = [NSApplication sharedApplication];
  NSWindow *w = [[NSWindow alloc] initWithContentRect:CGRectMake(200, 300, 420, 300) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [w setContentView:[[V alloc] initWithFrame:CGRectMake(0, 0, 420, 300)]];
  [w makeKeyAndOrderFront:nil];
  [a run];
} return 0; }
