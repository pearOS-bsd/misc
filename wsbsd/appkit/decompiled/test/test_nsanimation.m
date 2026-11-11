/* test_nsanimation.m — behaviour checks for NSAnimation core */
#import "../src/NSAnimation.h"
#import <math.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)
#define EQ(a,b) (fabs((a)-(b)) < 1e-6)

@interface ValueDelegate : NSObject <NSAnimationDelegate>
@property BOOL shouldStart;
@property BOOL stopped;
@end
@implementation ValueDelegate
- (BOOL)animationShouldStart:(NSAnimation *)a { return _shouldStart; }
- (void)animationDidStop:(NSAnimation *)a { _stopped = YES; }
- (float)animation:(NSAnimation *)a valueForProgress:(NSAnimationProgress)p { return 0.42f; }
@end

int main(void) {
    @autoreleasepool {
        /* designated init */
        NSAnimation *a = [[NSAnimation alloc] initWithDuration:2.0 animationCurve:NSAnimationLinear];
        CHECK(EQ(a.duration, 2.0), "duration set");
        CHECK(a.animationCurve == NSAnimationLinear, "curve set");
        CHECK(a.animationBlockingMode == NSAnimationBlocking, "default blocking mode");
        CHECK(EQ(a.frameRate, 60.0), "default frameRate 60");
        CHECK(!a.isAnimating, "not animating initially");

        /* plain init defaults */
        NSAnimation *d = [[NSAnimation alloc] init];
        CHECK(EQ(d.duration, 0.0) && d.animationCurve == NSAnimationEaseInOut, "init defaults");

        /* currentProgress clamps to [0,1] */
        a.currentProgress = 0.5f;  CHECK(EQ(a.currentProgress, 0.5f), "progress 0.5");
        a.currentProgress = 2.0f;  CHECK(EQ(a.currentProgress, 1.0f), "progress clamps high");
        a.currentProgress = -1.0f; CHECK(EQ(a.currentProgress, 0.0f), "progress clamps low");

        /* currentValue: linear == progress; endpoints exact for all curves */
        a.currentProgress = 0.3f;
        CHECK(EQ(a.currentValue, 0.3f), "linear currentValue == progress");
        for (NSAnimationCurve c = NSAnimationEaseInOut; c <= NSAnimationLinear; c++) {
            a.animationCurve = c;
            a.currentProgress = 0.0f; CHECK(EQ(a.currentValue, 0.0f), "curve value at 0");
            a.currentProgress = 1.0f; CHECK(EQ(a.currentValue, 1.0f), "curve value at 1");
        }
        /* ease-in-out monotonic through the middle */
        a.animationCurve = NSAnimationEaseInOut;
        a.currentProgress = 0.25f; float v1 = a.currentValue;
        a.currentProgress = 0.75f; float v2 = a.currentValue;
        CHECK(v1 < v2 && v1 > 0.0f && v2 < 1.0f, "ease-in-out monotonic interior");

        /* delegate valueForProgress overrides */
        ValueDelegate *vd = [ValueDelegate new];
        a.delegate = vd;
        CHECK(EQ(a.currentValue, 0.42f), "delegate supplies currentValue");
        a.delegate = nil;

        /* progress marks: sorted, unique, add/remove/set */
        NSAnimation *m = [[NSAnimation alloc] initWithDuration:1 animationCurve:NSAnimationLinear];
        [m addProgressMark:0.5f];
        [m addProgressMark:0.1f];
        [m addProgressMark:0.5f];               /* dup ignored */
        CHECK(m.progressMarks.count == 2, "marks deduped");
        CHECK(EQ([m.progressMarks[0] floatValue], 0.1f), "marks sorted");
        [m removeProgressMark:0.1f];
        CHECK(m.progressMarks.count == 1 && EQ([m.progressMarks[0] floatValue], 0.5f), "mark removed");
        m.progressMarks = @[@0.9f, @0.2f, @0.2f];
        CHECK(m.progressMarks.count == 2 && EQ([m.progressMarks[0] floatValue], 0.2f), "setProgressMarks re-sorts/dedups");

        /* linked animations wire & clear without crashing */
        NSAnimation *b = [[NSAnimation alloc] initWithDuration:1 animationCurve:NSAnimationLinear];
        [a startWhenAnimation:b reachesProgress:0.5f];
        [a stopWhenAnimation:b reachesProgress:0.9f];
        [a clearStartAnimation];
        [a clearStopAnimation];
        CHECK(1, "linked animation wiring safe");

        /* start/stop: delegate gating + animating flag + didStop */
        ValueDelegate *g = [ValueDelegate new];
        g.shouldStart = NO;
        NSAnimation *s = [[NSAnimation alloc] initWithDuration:1 animationCurve:NSAnimationLinear];
        s.delegate = g;
        [s startAnimation];
        CHECK(!s.isAnimating, "animationShouldStart:NO blocks start");
        g.shouldStart = YES;
        [s startAnimation];
        CHECK(s.isAnimating, "start sets animating");
        [s stopAnimation];
        CHECK(!s.isAnimating && g.stopped, "stop clears animating and calls animationDidStop:");

        /* copy carries value model */
        m.currentProgress = 0.4f;
        NSAnimation *cp = [m copy];
        CHECK(EQ(cp.duration, m.duration) && cp.progressMarks.count == m.progressMarks.count
              && EQ(cp.currentProgress, 0.4f), "copy carries value model");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
