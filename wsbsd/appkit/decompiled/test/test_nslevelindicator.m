/* test_nslevelindicator.m — NSLevelIndicator delegating numerics to its cell. */
#import "../src/NSLevelIndicator.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSLevelIndicator *li = [[NSLevelIndicator alloc] initWithFrame:CGRectMake(0, 0, 100, 18)];
        CHECK([li.cell isKindOfClass:[NSLevelIndicatorCell class]], "cell is NSLevelIndicatorCell");
        CHECK(li.minValue == 0.0, "default minValue 0");

        li.minValue = 1.0; li.maxValue = 10.0;
        li.warningValue = 6.0; li.criticalValue = 9.0;
        li.numberOfTickMarks = 10;
        CHECK(li.minValue == 1.0 && li.maxValue == 10.0, "min/max round-trip");
        CHECK(li.warningValue == 6.0 && li.criticalValue == 9.0, "warning/critical round-trip");
        CHECK(li.numberOfTickMarks == 10, "tick marks round-trip");
        CHECK([(NSLevelIndicatorCell *)li.cell warningValue] == 6.0, "stored on the cell");
        CHECK([li isKindOfClass:[NSControl class]], "is an NSControl");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
