/* test_nscombobox.m — NSComboBox over NSComboBoxCell (+NSTextField). */
#import "../src/NSComboBox.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSComboBox *cb = [[NSComboBox alloc] initWithFrame:CGRectMake(0, 0, 160, 24)];
        CHECK([cb.cell isKindOfClass:[NSComboBoxCell class]], "cell is NSComboBoxCell");

        /* inherits NSTextField string value */
        cb.stringValue = @"typed";
        CHECK([cb.stringValue isEqualToString:@"typed"], "inherits stringValue");

        cb.numberOfVisibleItems = 8;
        CHECK(cb.numberOfVisibleItems == 8, "numberOfVisibleItems round-trips");
        cb.numberOfVisibleItems = 100000;
        CHECK(cb.numberOfVisibleItems == 0xffff, "numberOfVisibleItems capped at 0xffff");

        cb.usesDataSource = YES;
        CHECK(cb.usesDataSource, "usesDataSource round-trips");
        /* usesDataSource and numberOfVisibleItems share the flags word independently */
        CHECK(cb.numberOfVisibleItems == 0xffff, "usesDataSource does not disturb the count");

        cb.hasVerticalScroller = NO;
        CHECK(!cb.hasVerticalScroller, "hasVerticalScroller round-trips");

        cb.usesDataSource = NO;
        [cb addItemWithObjectValue:@"One"];
        [cb addItemWithObjectValue:@"Two"];
        CHECK(cb.numberOfItems == 2, "items added");
        CHECK([[cb itemObjectValueAtIndex:1] isEqual:@"Two"], "item value at index");

        CHECK([cb isKindOfClass:[NSTextField class]], "NSComboBox is an NSTextField");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
