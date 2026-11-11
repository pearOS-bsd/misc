/* test_nsviewanimation.m — behaviour checks for NSViewAnimation core */
#import "../src/NSViewAnimation.h"
#import <math.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)
#define EQ(a,b) (fabs((a)-(b)) < 1e-4)

/* Minimal frame target that records the last frame it was given. */
@interface FrameTarget : NSObject
@property (nonatomic) NSRect frame;
@end
@implementation FrameTarget
- (void)setFrame:(NSRect)f { _frame = f; }
@end

int main(void) {
    @autoreleasepool {
        /* inherits NSAnimation, default 0.5s ease-in-out timeline */
        FrameTarget *t = [FrameTarget new];
        NSDictionary *anim = @{
            NSViewAnimationTargetKey:     t,
            NSViewAnimationStartFrameKey: [NSValue valueWithRect:NSMakeRect(0, 0, 100, 100)],
            NSViewAnimationEndFrameKey:   [NSValue valueWithRect:NSMakeRect(100, 200, 300, 400)],
        };
        NSViewAnimation *va = [[NSViewAnimation alloc] initWithViewAnimations:@[anim]];
        CHECK([va isKindOfClass:[NSAnimation class]], "NSViewAnimation is an NSAnimation");
        CHECK(EQ(va.duration, 0.5), "default duration 0.5");
        CHECK(va.animationCurve == NSAnimationEaseInOut, "default ease-in-out");
        CHECK(va.viewAnimations.count == 1, "viewAnimations stored");

        /* progress 0 -> start frame */
        va.animationCurve = NSAnimationLinear;   /* value==progress for exact math */
        va.currentProgress = 0.0f;
        CHECK(EQ(t.frame.origin.x, 0) && EQ(t.frame.size.width, 100), "progress 0 -> start frame");

        /* progress 1 -> end frame */
        va.currentProgress = 1.0f;
        CHECK(EQ(t.frame.origin.x, 100) && EQ(t.frame.origin.y, 200)
              && EQ(t.frame.size.width, 300) && EQ(t.frame.size.height, 400),
              "progress 1 -> end frame");

        /* progress 0.5 (linear) -> midpoint */
        va.currentProgress = 0.5f;
        CHECK(EQ(t.frame.origin.x, 50) && EQ(t.frame.origin.y, 100)
              && EQ(t.frame.size.width, 200) && EQ(t.frame.size.height, 250),
              "progress 0.5 -> linear midpoint");

        /* curve is honoured: ease-in at 0.5 moves less than halfway in x */
        va.animationCurve = NSAnimationEaseIn;    /* value = p*p = 0.25 at p=0.5 */
        va.currentProgress = 0.5f;
        CHECK(EQ(t.frame.origin.x, 25), "ease-in curve applied to frame interpolation");

        /* setViewAnimations replaces */
        va.viewAnimations = @[];
        CHECK(va.viewAnimations.count == 0, "setViewAnimations replaces");

        /* keys are distinct non-empty constants */
        CHECK(![NSViewAnimationTargetKey isEqual:NSViewAnimationEndFrameKey]
              && NSViewAnimationFadeInEffect.length && NSViewAnimationFadeOutEffect.length,
              "effect/key constants defined");

        /* plain init -> empty, safe setCurrentProgress */
        NSViewAnimation *empty = [[NSViewAnimation alloc] init];
        empty.currentProgress = 0.5f;
        CHECK(empty.viewAnimations.count == 0, "empty init safe");

        /* copy carries descriptors */
        NSViewAnimation *va2 = [[NSViewAnimation alloc] initWithViewAnimations:@[anim]];
        NSViewAnimation *cp = [va2 copy];
        CHECK(cp.viewAnimations.count == 1 && EQ(cp.duration, 0.5), "copy carries descriptors+timeline");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
