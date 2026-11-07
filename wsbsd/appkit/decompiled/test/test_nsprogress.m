/*
 * test_nsprogress.m — NSProgressIndicator numeric core: min/max, doubleValue
 * clamping, incrementBy:, indeterminate/style.
 */
#import "../src/NSProgressIndicator.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        NSProgressIndicator *p = [[NSProgressIndicator alloc] initWithFrame:CGRectMake(0, 0, 200, 20)];

        /* defaults */
        CHECK(p.minValue == 0.0, "default minValue 0");
        CHECK(p.maxValue == 100.0, "default maxValue 100");
        CHECK(p.isIndeterminate == YES, "default indeterminate YES");
        CHECK(p.style == NSProgressIndicatorStyleBar, "default style bar");

        /* doubleValue clamps to [min,max] */
        p.doubleValue = 40.0;
        CHECK(p.doubleValue == 40.0, "value in range stored");
        p.doubleValue = 250.0;
        CHECK(p.doubleValue == 100.0, "value above max clamped to max");
        p.doubleValue = -5.0;
        CHECK(p.doubleValue == 0.0, "value below min clamped to min");

        /* custom range */
        p.minValue = -10.0;
        p.maxValue = 10.0;
        p.doubleValue = 5.0;
        CHECK(p.doubleValue == 5.0, "value within custom range");
        p.doubleValue = 100.0;
        CHECK(p.doubleValue == 10.0, "clamp to custom max");

        /* incrementBy with clamp */
        p.doubleValue = 9.0;
        [p incrementBy:5.0];
        CHECK(p.doubleValue == 10.0, "incrementBy clamps at max");
        [p incrementBy:-100.0];
        CHECK(p.doubleValue == -10.0, "incrementBy clamps at min");

        /* flags */
        p.indeterminate = NO;
        CHECK(!p.isIndeterminate, "indeterminate cleared");
        p.style = NSProgressIndicatorStyleSpinning;
        CHECK(p.style == NSProgressIndicatorStyleSpinning, "style round-trips");

        /* it is an NSView */
        CHECK([p isKindOfClass:[NSView class]], "NSProgressIndicator is an NSView");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
