/* The first AppKit program on the open AppKit: a window with a view that draws. Built with the headers of appkit/decompiled/src. */
#import "NSApplication.h"
#import "NSWindow.h"
#import "NSView.h"
#import "NSColor.h"
#import "NSFont.h"
#import "NSButton.h"
#import "NSTextField.h"
#import "NSEvent.h"

@interface V : NSView { BOOL on; } @end
static id sT;
@interface T : NSObject
- (void)hit:(id)s;
@end

@implementation T
- (void)hit:(id)s { fprintf(stderr, "open-hello: button action\n"); }
@end
@implementation V
- (void)mouseDown:(NSEvent *)e { on = !on; fprintf(stderr, "open-hello: mouseDown at %g,%g\n", e ? [e locationInWindow].x : -1, e ? [e locationInWindow].y : -1); [self setNeedsDisplay:YES]; }
- (void)keyDown:(NSEvent *)e { fprintf(stderr, "open-hello: keyDown %d chars='%s'\n", (int)[e keyCode], [[e characters] UTF8String]); }
- (void)drawRect:(CGRect)r { [(on ? [NSColor greenColor] : [NSColor yellowColor]) setFill]; NSRectFill([self bounds]); [[NSColor redColor] setFill]; NSRectFill(CGRectMake(20, 20, 120, 60));
  [@"open: AppKit on wsd" drawAtPoint:CGPointMake(20, 200) withAttributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:28], NSForegroundColorAttributeName: [NSColor blackColor] }]; }
@end
int main(void) { @autoreleasepool {
  NSApplication *a = [NSApplication sharedApplication];
  NSWindow *w = [[NSWindow alloc] initWithContentRect:CGRectMake(200, 300, 420, 300) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO]; [w setTitle:@"open: hello"];
  [w setContentView:[[V alloc] initWithFrame:CGRectMake(0, 0, 420, 300)]];
  { NSButton *b = [NSButton buttonWithTitle:@"Click me" target:(sT = [T new]) action:@selector(hit:)]; [b setFrame:CGRectMake(250, 20, 120, 32)]; [[w contentView] addSubview:b]; }
  { NSTextField *tf = [[NSTextField alloc] initWithFrame:CGRectMake(20, 100, 200, 24)]; [tf setBezeled:YES]; [tf setEditable:YES]; [tf setStringValue:@""]; [[w contentView] addSubview:tf]; }
  [w makeKeyAndOrderFront:nil];
  V *cv = (V *)[w contentView];
  [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer *t) { static int n; fprintf(stderr, "open-hello: tick %d\n", ++n); [cv mouseDown:nil]; }];
  [a run];
} return 0; }
