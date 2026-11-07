/* test_nspopupbutton.m — NSPopUpButton over NSPopUpButtonCell + NSMenu. */
#import "../src/NSPopUpButton.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSPopUpButton *pop = [[NSPopUpButton alloc] initWithFrame:CGRectMake(0, 0, 120, 24)];
        CHECK([pop.cell isKindOfClass:[NSPopUpButtonCell class]], "cell is NSPopUpButtonCell");
        CHECK(pop.numberOfItems == 0, "empty to start");
        CHECK(pop.indexOfSelectedItem == -1, "nothing selected to start");

        [pop addItemWithTitle:@"One"];
        [pop addItemWithTitle:@"Two"];
        [pop addItemWithTitle:@"Three"];
        CHECK(pop.numberOfItems == 3, "three items (via NSMenu)");
        CHECK(pop.indexOfSelectedItem == 0, "first added item is selected");
        CHECK([[pop titleOfSelectedItem] isEqualToString:@"One"], "selected title is first");

        [pop selectItemAtIndex:2];
        CHECK(pop.indexOfSelectedItem == 2, "selectItemAtIndex updates selection");
        CHECK([[pop titleOfSelectedItem] isEqualToString:@"Three"], "selected title follows index");
        CHECK(pop.selectedItem == [((NSPopUpButtonCell *)pop.cell).menu itemAtIndex:2], "selectedItem is the menu item");

        /* out-of-range select is ignored */
        [pop selectItemAtIndex:99];
        CHECK(pop.indexOfSelectedItem == 2, "out-of-range select ignored");

        pop.pullsDown = YES;
        CHECK(pop.pullsDown, "pullsDown round-trips");

        CHECK([pop isKindOfClass:[NSButton class]], "NSPopUpButton is an NSButton");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
