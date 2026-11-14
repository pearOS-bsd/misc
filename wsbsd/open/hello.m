/* The first AppKit program on the open AppKit: a window with a view that draws. Built with the headers of appkit/decompiled/src. */
#import "NSApplication.h"
#import "NSWindow.h"
#import "NSView.h"
#import "NSColor.h"
#import "NSFont.h"
#import "NSEvent.h"

@interface V : NSView { BOOL on; } @end
@implementation V
- (void)mouseDown:(NSEvent *)e { on = !on; fprintf(stderr, "open-hello: mouseDown at %g,%g\n", [e locationInWindow].x, [e locationInWindow].y); [self setNeedsDisplay:YES]; }
- (void)keyDown:(NSEvent *)e { fprintf(stderr, "open-hello: keyDown %d chars='%s'\n", (int)[e keyCode], [[e characters] UTF8String]); }
- (void)drawRect:(CGRect)r { [(on ? [NSColor greenColor] : [NSColor yellowColor]) setFill]; NSRectFill([self bounds]); [[NSColor redColor] setFill]; NSRectFill(CGRectMake(20, 20, 120, 60));
  [@"open: AppKit on wsd" drawAtPoint:CGPointMake(20, 200) withAttributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:28], NSForegroundColorAttributeName: [NSColor blackColor] }]; }
@end
int main(void) { @autoreleasepool {
  NSApplication *a = [NSApplication sharedApplication];
  NSWindow *w = [[NSWindow alloc] initWithContentRect:CGRectMake(200, 300, 420, 300) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
  [w setContentView:[[V alloc] initWithFrame:CGRectMake(0, 0, 420, 300)]];
  [w makeKeyAndOrderFront:nil];
  [a run];
} return 0; }
