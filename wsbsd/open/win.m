// an ordinary Cocoa program: nothing of "open" in it. cc -arch x86_64 -o win win.m -framework Cocoa
#import <Cocoa/Cocoa.h>
@interface V : NSView @end
@implementation V
- (void)drawRect:(NSRect)r { [[NSColor yellowColor] setFill]; NSRectFill([self bounds]);
  [@"unmodified Mac binary" drawAtPoint:NSMakePoint(20, 150) withAttributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:24], NSForegroundColorAttributeName: [NSColor blackColor] }]; }
@end
int main(void) { @autoreleasepool {
  NSApplication *a = [NSApplication sharedApplication];
  NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(200, 300, 420, 300) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [w setTitle:@"win (unmodified)"]; [w setContentView:[[V alloc] initWithFrame:NSMakeRect(0, 0, 420, 300)]];
  [w makeKeyAndOrderFront:nil]; [a run];
} return 0; }
