/* test_nsscroller.m — NSScroller: knobProportion/doubleValue clamp, scrollerStyle. */
#import "../src/NSScroller.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSScroller *s = [[NSScroller alloc] initWithFrame:CGRectMake(0, 0, 16, 200)];

        s.doubleValue = 0.5;
        CHECK(s.doubleValue == 0.5, "doubleValue in range");
        s.doubleValue = 2.0;
        CHECK(s.doubleValue == 1.0, "doubleValue clamped to 1");
        s.doubleValue = -1.0;
        CHECK(s.doubleValue == 0.0, "doubleValue clamped to 0");

        s.knobProportion = 0.25;
        CHECK(s.knobProportion == 0.25, "knobProportion in range");
        s.knobProportion = 5.0;
        CHECK(s.knobProportion == 1.0, "knobProportion clamped to 1");

        CHECK(s.scrollerStyle == NSScrollerStyleLegacy, "default style legacy");
        s.scrollerStyle = NSScrollerStyleOverlay;
        CHECK(s.scrollerStyle == NSScrollerStyleOverlay, "scrollerStyle round-trips");
        /* style change does not disturb the value */
        CHECK(s.knobProportion == 1.0, "style change leaves knobProportion intact");

        CHECK([s isKindOfClass:[NSControl class]], "NSScroller is an NSControl");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
