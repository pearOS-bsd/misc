/* test_nstabviewcontroller.m — NSTabViewController tab + child sync. */
#import "../src/NSTabViewController.h"
#import "../src/NSTabViewItem.h"
#import "../src/NSViewController.h"
#import "../src/NSView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTabViewController *tvc = [[NSTabViewController alloc] initWithNibName:nil bundle:nil];
        CHECK([tvc isKindOfClass:[NSViewController class]], "is an NSViewController");
        CHECK(tvc.tabStyle == NSTabViewControllerTabStyleSegmentedControlOnTop, "default tab style");
        CHECK(tvc.tabViewItems.count == 0, "no items initially");
        CHECK(tvc.selectedTabViewItemIndex == -1, "no selection initially");

        NSViewController *vc1 = [[NSViewController alloc] init];
        NSViewController *vc2 = [[NSViewController alloc] init];
        NSTabViewItem *i1 = [NSTabViewItem tabViewItemWithViewController:vc1];
        NSTabViewItem *i2 = [NSTabViewItem tabViewItemWithViewController:vc2];

        [tvc addTabViewItem:i1];
        CHECK(tvc.tabViewItems.count == 1, "one item added");
        CHECK(tvc.selectedTabViewItemIndex == 0, "first item becomes selected");
        CHECK(vc1.parentViewController == tvc, "item's view controller added as child");

        [tvc addTabViewItem:i2];
        CHECK(tvc.childViewControllers.count == 2, "two child view controllers");
        CHECK([tvc tabViewItemForViewController:vc2] == i2, "tabViewItemForViewController finds i2");

        /* selection clamping */
        tvc.selectedTabViewItemIndex = 5;
        CHECK(tvc.selectedTabViewItemIndex == 1, "selection clamped to last index");
        tvc.selectedTabViewItemIndex = -3;
        CHECK(tvc.selectedTabViewItemIndex == 0, "selection clamped to 0");

        /* insert at index */
        NSViewController *vc0 = [[NSViewController alloc] init];
        NSTabViewItem *i0 = [NSTabViewItem tabViewItemWithViewController:vc0];
        [tvc insertTabViewItem:i0 atIndex:0];
        CHECK(tvc.tabViewItems[0] == i0, "inserted at index 0");
        CHECK(tvc.childViewControllers.count == 3, "child count grew");

        /* removal detaches child and keeps selection valid */
        [tvc removeTabViewItem:i2];
        CHECK(tvc.tabViewItems.count == 2, "item removed");
        CHECK(vc2.parentViewController == nil, "removed item's controller detached");
        CHECK(tvc.selectedTabViewItemIndex <= 1, "selection stays in range after removal");

        /* setTabViewItems resets */
        [tvc setTabViewItems:@[i1]];
        CHECK(tvc.tabViewItems.count == 1 && tvc.tabViewItems[0] == i1, "setTabViewItems replaces the set");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
