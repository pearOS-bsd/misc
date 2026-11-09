/* test_nsgesturerecognizer.m — NSGestureRecognizer core. */
#import "../src/NSGestureRecognizer.h"
#import <objc/runtime.h>

/* expose the internal state setter for the test */
@interface NSGestureRecognizer (TestInternal)
- (void)_setState:(NSGestureRecognizerState)state;
@end

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        id tgt = [NSObject new];
        NSGestureRecognizer *g = [[NSGestureRecognizer alloc] initWithTarget:tgt action:@selector(handle:)];
        CHECK(g.target == tgt, "target from init");
        CHECK(sel_isEqual(g.action, @selector(handle:)), "action from init");
        CHECK(g.isEnabled == YES, "enabled by default");
        CHECK(g.state == NSGestureRecognizerStatePossible, "state starts Possible");

        g.enabled = NO;
        CHECK(!g.isEnabled, "enabled round-trips");

        id tgt2 = [NSObject new];
        g.target = tgt2;
        g.action = @selector(other:);
        CHECK(g.target == tgt2, "target round-trips");
        CHECK(sel_isEqual(g.action, @selector(other:)), "action round-trips");

        /* subclasses advance the state machine */
        [g _setState:NSGestureRecognizerStateBegan];
        CHECK(g.state == NSGestureRecognizerStateBegan, "state advances to Began");
        [g _setState:NSGestureRecognizerStateEnded];
        CHECK(g.state == NSGestureRecognizerStateRecognized, "Ended == Recognized");

        /* weak target */
        @autoreleasepool {
            id tmp = [NSObject new];
            g.target = tmp;
            CHECK(g.target == tmp, "weak target held while alive");
        }
        CHECK(g.target == nil, "weak target cleared after dealloc");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
