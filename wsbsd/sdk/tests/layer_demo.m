/* Layer-backed views on the GNUstep backend: a window with a layer-backed content view, layer-backed subviews, a Core Animation rotation / position animation on one of them, the animator proxy on another.
 * Self-test (exit status): the layer tree follows the views, the contents are made, and the animation runs on the presentation layer. WS_DEMO_HOLD=1 keeps the window open for a screenshot. */
#import <AppKit/AppKit.h>
#import <wsbsd/AppKitCompat.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAWsbsd.h>

static int failures;
#define CHECK(c, ...) do { if (!(c)) { failures++; printf("FAIL: " __VA_ARGS__); printf("\n"); fflush(stdout); } } while (0)
@interface Box : NSView { NSColor *c; NSString *t; } - (id)initWithFrame:(NSRect)f color:(NSColor *)col title:(NSString *)title; @end
@implementation Box
- (id)initWithFrame:(NSRect)f color:(NSColor *)col title:(NSString *)title { if ((self = [super initWithFrame: f])) { c = col; t = title; } return self; }
- (void)drawRect:(NSRect)r { [c set]; NSRectFill([self bounds]); [t drawAtPoint: NSMakePoint(8, 8) withAttributes: nil]; }
@end

extern char **environ;
/* the events and the display of the windows, as the application loop does it */
static void Pump(NSApplication *app, double seconds)
{
	NSDate *end = [NSDate dateWithTimeIntervalSinceNow: seconds];
	while ([end timeIntervalSinceNow] > 0) {
		NSEvent *e = [app nextEventMatchingMask: NSAnyEventMask untilDate: [NSDate dateWithTimeIntervalSinceNow: 0.02] inMode: NSDefaultRunLoopMode dequeue: YES];
		if (e) [app sendEvent: e];
		[app updateWindows];
	}
}
int main(int argc, char *argv[])
{
#ifdef GNUSTEP
	[NSProcessInfo initializeWithArguments: argv count: argc environment: environ];      /* no procfs in the VM: the arguments are given */
#endif
	@autoreleasepool {
		NSApplication *app = [NSApplication sharedApplication]; [app finishLaunching];
		NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 100, 480, 320) styleMask: NSTitledWindowMask | NSClosableWindowMask backing: NSBackingStoreBuffered defer: NO];
		NSView *root = [[Box alloc] initWithFrame: NSMakeRect(0, 0, 480, 320) color: [NSColor colorWithCalibratedWhite: 0.92 alpha: 1] title: @"layer-backed root"];
		[root setWantsLayer: YES];
		[w setContentView: root];
		Box *a = [[Box alloc] initWithFrame: NSMakeRect(30, 40, 140, 100) color: [NSColor redColor] title: @"A (CA rotation)"];
		Box *b = [[Box alloc] initWithFrame: NSMakeRect(200, 40, 140, 100) color: [NSColor blueColor] title: @"B (animator)"];
		Box *c = [[Box alloc] initWithFrame: NSMakeRect(30, 180, 140, 100) color: [NSColor greenColor] title: @"C (still)"];
		for (NSView *v in @[a, b, c]) { [v setWantsLayer: YES]; [root addSubview: v]; }
		[w makeKeyAndOrderFront: nil];
		[root display];
		CHECK([[root layer] sublayers].count == 3, "root layer has %d sublayers", (int)[[root layer] sublayers].count);
		CHECK(CGRectEqualToRect([[a layer] frame], CGRectMake(30, 40, 140, 100)), "A frame %s", [NSStringFromRect(NSRectFromCGRect([[a layer] frame])) UTF8String]);
		CHECK([[a layer] contents] != nil, "A has contents");
		CABasicAnimation *rot = [CABasicAnimation animationWithKeyPath: @"transform.rotation.z"];
		rot.fromValue = @0; rot.toValue = @(M_PI / 4); rot.duration = 1; rot.fillMode = kCAFillModeForwards; rot.removedOnCompletion = NO;
		if (getenv("WS_DEMO_HOLD")) { rot.repeatCount = 1e6; rot.autoreverses = YES; }
		[[a layer] addAnimation: rot forKey: @"rot"];
		[NSAnimationContext runAnimationGroup: ^(NSAnimationContext *ctx) { ctx.duration = 1; [[b animator] setFrame: NSMakeRect(300, 120, 140, 100)]; } completionHandler: nil];
		CHECK(CALayerTreeHasActiveAnimations([root layer]), "an animation is running");
		Pump(app, 0.5);
		CALayer *p = [[a layer] presentationLayer];
		double ang = p ? atan2([p transform].m12, [p transform].m11) : -1;
		CHECK(p != nil && ang > 0.1 && ang < M_PI / 4, "rotation at 0.5 s: %g (presentation layer %s)", ang, p ? "present" : "nil");
		{	/* the tree as the view renders it: a point near the bottom-right corner of A is no longer red while A is rotated (the layer rotates about its lower-left corner) */
			CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
			CGContextRef cg = CGBitmapContextCreate(NULL, 480, 320, 8, 480 * 4, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
			CARenderPresentation([root layer], cg, 0, NO);
			const unsigned char *px = CGBitmapContextGetData(cg);
			size_t row = 320 - 1 - 50;       /* the context is y up, the rows are from the top */
			unsigned bgra = *(const unsigned *)(px + row * 480 * 4 + 160 * 4);
			CHECK(bgra != 0xFFFF0000u, "the pixel of A is still red: the rotation is not rendered (%08x)", bgra);
			CGContextRelease(cg); CGColorSpaceRelease(cs);
		}
		CHECK([a frame].origin.x == 30, "model frame of A kept");
		printf("rotation %.3f anim=%d\n", ang, (int)CALayerTreeHasActiveAnimations([root layer]));
		printf(failures ? "layer_demo: %d failure(s)\n" : "layer_demo: ok\n", failures); fflush(stdout);
		if (getenv("WS_DEMO_HOLD")) Pump(app, 600);
		(void)app;
	}
	return failures != 0;
}
