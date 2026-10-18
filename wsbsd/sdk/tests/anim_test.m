/* The animator proxies and NSAnimationContext against the curves of Core Animation: a frame animation of 0.4 s with the default timing function is sampled and compared with the
 * values of Apple's curve (cubic bezier 0.25 0.1 0.25 1); the completion handler runs once, after the end. */
#import <AppKit/AppKit.h>
#import <wsbsd/AppKitCompat.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAWsbsd.h>

static int failures;
static NSMutableArray *gSamples; static CFTimeInterval gStart;
@interface SampleView : NSView @end
@implementation SampleView
- (void)setFrame:(NSRect)f { [super setFrame: f]; [gSamples addObject: @[@(CACurrentMediaTime() - gStart), @(f.origin.x)]]; }
@end
#define CHECK(c, ...) do { if (!(c)) { failures++; printf("FAIL: " __VA_ARGS__); printf("\n"); } } while (0)

int main(void)
{
	@autoreleasepool {
		NSView *v = [[SampleView alloc] initWithFrame: NSMakeRect(0, 0, 100, 100)];
		NSMutableArray *samples = gSamples = [NSMutableArray array]; __block int completed = 0; __block CFTimeInterval doneAt = 0;
		CFTimeInterval start = gStart = CACurrentMediaTime();
		[NSAnimationContext runAnimationGroup: ^(NSAnimationContext *c) {
			c.duration = 0.4;
			[[v animator] setFrame: NSMakeRect(100, 50, 300, 200)];
		} completionHandler: ^{ completed++; doneAt = CACurrentMediaTime() - start; }];
		CHECK(NSEqualRects([v frame], NSMakeRect(0, 0, 100, 100)), "the frame did not move at once: %s", [NSStringFromRect([v frame]) UTF8String]);
		[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.7]];
		CHECK(completed == 1, "completion handler ran %d times", completed);
		CHECK(doneAt >= 0.39 && doneAt < 0.6, "completion at %.3f s", doneAt);
		CHECK(NSEqualRects([v frame], NSMakeRect(100, 50, 300, 200)), "final frame %s", [NSStringFromRect([v frame]) UTF8String]);
		CAMediaTimingFunction *f = [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionDefault];
		double worst = 0; int n = 0;
		for (NSArray *s in samples) {
			double ts = [s[0] doubleValue], x = [s[1] doubleValue];
			if (ts > 0.38 || ts < 0.05) continue;
			double u = ts / 0.4; float c1[2], c2[2]; [f getControlPointAtIndex: 1 values: c1]; [f getControlPointAtIndex: 2 values: c2];
			/* the expected x: the curve solved by bisection */
			double lo = 0, hi = 1, tt = u; for (int i = 0; i < 60; i++) { tt = (lo + hi) / 2; double bx = 3 * (1 - tt) * (1 - tt) * tt * c1[0] + 3 * (1 - tt) * tt * tt * c2[0] + tt * tt * tt; if (bx < u) lo = tt; else hi = tt; }
			double by = 3 * (1 - tt) * (1 - tt) * tt * c1[1] + 3 * (1 - tt) * tt * tt * c2[1] + tt * tt * tt;
			double want = 0 + (100 - 0) * by; worst = fmax(worst, fabs(want - x)); n++;
		}
		CHECK(n > 5 && worst < 3, "curve deviation %.2f over %d samples", worst, n);
		/* a second animation replaces the first one */
		[NSAnimationContext runAnimationGroup: ^(NSAnimationContext *c) { c.duration = 1.0; [[v animator] setAlphaValue: 0.0]; [[v animator] setFrameOrigin: NSMakePoint(0, 0)]; } completionHandler: nil];
		[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.2]];
		CHECK([v frame].origin.x < 100 && [v frame].origin.x > 0, "origin is in between: %.2f", [v frame].origin.x);
		CHECK(NSEqualSizes([v frame].size, NSMakeSize(300, 200)), "size untouched by frameOrigin animation");
		/* nested contexts inherit the duration */
		[NSAnimationContext beginGrouping]; [NSAnimationContext currentContext].duration = 2.5; [NSAnimationContext beginGrouping];
		CHECK([NSAnimationContext currentContext].duration == 2.5, "inner context starts from the outer settings"); [NSAnimationContext endGrouping]; [NSAnimationContext endGrouping];
		CHECK([NSAnimationContext currentContext].duration == 0.25, "default duration is 0.25");
	}
	printf(failures ? "FAILED (%d)\n" : "ok: animator proxies and contexts\n", failures);
	return failures != 0;
}
