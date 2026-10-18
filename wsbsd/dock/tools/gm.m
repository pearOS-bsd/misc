#import <Cocoa/Cocoa.h>
@interface GV : NSView @end
@implementation GV
- (void)drawRect:(NSRect)r { [[NSColor colorWithCalibratedRed:0.1 green:0.4 blue:0.9 alpha:1] setFill]; NSRectFill(self.bounds);
 [[NSColor whiteColor] setStroke]; for (int i=0;i<=12;i++){ NSBezierPath *p=[NSBezierPath bezierPath]; [p moveToPoint:NSMakePoint(i*self.bounds.size.width/12,0)]; [p lineToPoint:NSMakePoint(i*self.bounds.size.width/12,self.bounds.size.height)]; [p stroke]; p=[NSBezierPath bezierPath]; [p moveToPoint:NSMakePoint(0,i*self.bounds.size.height/12)]; [p lineToPoint:NSMakePoint(self.bounds.size.width,i*self.bounds.size.height/12)]; [p stroke]; }
 [[NSColor redColor] setFill]; NSRectFill(NSMakeRect(0,self.bounds.size.height-20,self.bounds.size.width,20)); }
@end
int main(int argc,char**argv){ @autoreleasepool { NSApplication *a=[NSApplication sharedApplication]; [a setActivationPolicy:NSApplicationActivationPolicyRegular];
 NSWindow *w=[[NSWindow alloc] initWithContentRect:NSMakeRect(1500,500,600,420) styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskClosable backing:NSBackingStoreBuffered defer:NO];
 [w setContentView:[[GV alloc] initWithFrame:NSMakeRect(0,0,600,420)]]; [w setTitle:@"genie"]; [w setLevel:NSFloatingWindowLevel]; [w makeKeyAndOrderFront:nil]; [a activateIgnoringOtherApps:YES];
 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:atof(argv[1])]];
 [w miniaturize:nil]; fprintf(stderr,"mini at %f\n",CACurrentMediaTime());
 [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:3]]; } return 0; }
