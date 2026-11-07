/* test_nssearchfield.m — NSSearchField over NSSearchFieldCell (+NSTextField). */
#import "../src/NSSearchField.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSSearchField *sf = [[NSSearchField alloc] initWithFrame:CGRectMake(0, 0, 160, 22)];
        CHECK([sf.cell isKindOfClass:[NSSearchFieldCell class]], "cell is NSSearchFieldCell");

        /* inherits NSTextField string value */
        sf.stringValue = @"query";
        CHECK([sf.stringValue isEqualToString:@"query"], "inherits NSTextField stringValue");

        /* maximumRecents: the 0xff sentinel reads back as -1 ("default"). The
         * exact init default is stage2, so we only assert the mapping here. */
        sf.maximumRecents = 10;
        CHECK(sf.maximumRecents == 10, "maximumRecents round-trips");
        sf.maximumRecents = 9999;
        CHECK(sf.maximumRecents == 254, "maximumRecents capped at 254");
        sf.maximumRecents = -5;
        CHECK(sf.maximumRecents == -1, "negative resets to default");

        sf.sendsWholeSearchString = YES;
        CHECK(sf.sendsWholeSearchString, "sendsWholeSearchString round-trips");

        sf.recentSearches = @[@"a", @"b", @"c"];
        CHECK(sf.recentSearches.count == 3, "recentSearches round-trips");

        CHECK([sf isKindOfClass:[NSTextField class]], "NSSearchField is an NSTextField");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
