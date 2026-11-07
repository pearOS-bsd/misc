/*
 * test_nsstepper.m — NSStepper delegating numeric props to NSStepperCell:
 * default min/max/increment/wraps/autorepeat and round-trips.
 */
#import "../src/NSStepper.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        NSStepper *s = [[NSStepper alloc] initWithFrame:CGRectMake(0, 0, 19, 27)];
        CHECK([s.cell isKindOfClass:[NSStepperCell class]], "cell is NSStepperCell");

        /* AppKit defaults */
        CHECK(s.minValue == 0.0, "default minValue 0");
        CHECK(s.maxValue == 59.0, "default maxValue 59");
        CHECK(s.increment == 1.0, "default increment 1");
        CHECK(s.valueWraps == YES, "default valueWraps YES");
        CHECK(s.autorepeat == YES, "default autorepeat YES");

        /* round-trips through the cell */
        s.minValue = -10.0;
        s.maxValue = 10.0;
        s.increment = 0.5;
        CHECK(s.minValue == -10.0 && s.maxValue == 10.0 && s.increment == 0.5,
              "numeric props round-trip");
        CHECK([(NSStepperCell *)s.cell minValue] == -10.0, "value actually stored on the cell");

        s.valueWraps = NO;
        s.autorepeat = NO;
        CHECK(!s.valueWraps && !s.autorepeat, "flags round-trip");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
