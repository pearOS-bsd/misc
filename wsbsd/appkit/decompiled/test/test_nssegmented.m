/* test_nssegmented.m — NSSegmentedControl over NSSegmentedCell. */
#import "../src/NSSegmentedControl.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSSegmentedControl *sc = [[NSSegmentedControl alloc] initWithFrame:CGRectMake(0, 0, 200, 24)];
        CHECK([sc.cell isKindOfClass:[NSSegmentedCell class]], "cell is NSSegmentedCell");
        CHECK(sc.segmentCount == 0, "no segments to start");

        sc.segmentCount = 3;
        CHECK(sc.segmentCount == 3, "segmentCount round-trips");

        [sc setLabel:@"Day" forSegment:0];
        [sc setLabel:@"Week" forSegment:1];
        [sc setLabel:@"Month" forSegment:2];
        CHECK([[sc labelForSegment:1] isEqualToString:@"Week"], "per-segment label");

        [sc setWidth:40.0 forSegment:0];
        CHECK([sc widthForSegment:0] == 40.0, "per-segment width");

        sc.selectedSegment = 2;
        CHECK(sc.selectedSegment == 2, "selectedSegment round-trips");

        /* shrinking drops segments and clears an out-of-range selection */
        sc.segmentCount = 1;
        CHECK(sc.segmentCount == 1, "segmentCount shrinks");
        CHECK(sc.selectedSegment == -1, "selection cleared when out of range");
        CHECK([[sc labelForSegment:0] isEqualToString:@"Day"], "remaining segment keeps its label");

        /* over-limit raises */
        BOOL threw = NO;
        @try { sc.segmentCount = 0x1000; } @catch (NSException *e) { threw = YES; }
        CHECK(threw, "segmentCount over 0x800 raises");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
