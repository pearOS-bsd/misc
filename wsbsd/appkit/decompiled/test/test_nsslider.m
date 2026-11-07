/* test_nsslider.m — NSSlider delegating min/max/altIncrement/tickMarks to cell. */
#import "../src/NSSlider.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSSlider *s = [[NSSlider alloc] initWithFrame:CGRectMake(0, 0, 120, 20)];
        CHECK([s.cell isKindOfClass:[NSSliderCell class]], "cell is NSSliderCell");

        s.minValue = 10.0;
        s.maxValue = 90.0;
        CHECK(s.minValue == 10.0 && s.maxValue == 90.0, "min/max round-trip");
        CHECK([(NSSliderCell *)s.cell minValue] == 10.0, "stored on the cell");

        s.numberOfTickMarks = 5;
        CHECK(s.numberOfTickMarks == 5, "numberOfTickMarks round-trips");
        s.altIncrementValue = 2.5;
        CHECK(s.altIncrementValue == 2.5, "altIncrementValue round-trips");

        CHECK([s isKindOfClass:[NSControl class]], "NSSlider is an NSControl");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
