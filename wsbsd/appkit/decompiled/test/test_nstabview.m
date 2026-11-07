/* test_nstabview.m — NSTabView managing NSTabViewItems. */
#import "../src/NSTabView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTabView *tv = [[NSTabView alloc] initWithFrame:CGRectMake(0, 0, 300, 200)];
        CHECK(tv.numberOfTabViewItems == 0, "empty to start");
        CHECK(tv.selectedTabViewItem == nil, "nothing selected");

        NSTabViewItem *a = [[NSTabViewItem alloc] initWithIdentifier:@"a"];
        a.label = @"General";
        NSTabViewItem *b = [[NSTabViewItem alloc] initWithIdentifier:@"b"];
        b.label = @"Advanced";
        [tv addTabViewItem:a];
        [tv addTabViewItem:b];

        CHECK(tv.numberOfTabViewItems == 2, "two items");
        CHECK(tv.tabViewItems.count == 2, "tabViewItems lists both");
        CHECK([tv tabViewItemAtIndex:0] == a, "item at index 0");
        CHECK([tv indexOfTabViewItem:b] == 1, "indexOfTabViewItem");
        CHECK(tv.selectedTabViewItem == a, "first item selected by default");
        CHECK([a.label isEqualToString:@"General"], "item label round-trips");
        CHECK([a.identifier isEqualToString:@"a"], "item identifier set from init");

        [tv selectTabViewItemAtIndex:1];
        CHECK(tv.selectedTabViewItem == b, "selection follows index");

        /* a view can be attached to an item */
        NSView *v = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        a.view = v;
        CHECK(a.view == v, "item view round-trips");

        [tv removeTabViewItem:a];
        CHECK(tv.numberOfTabViewItems == 1 && [tv indexOfTabViewItem:a] == (NSInteger)NSNotFound,
              "removeTabViewItem drops it");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
