/* test_nssplitviewcontroller.m — NSSplitViewController item + child sync. */
#import "../src/NSSplitViewController.h"
#import "../src/NSSplitViewItem.h"
#import "../src/NSViewController.h"
#import "../src/NSView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSSplitViewController *svc = [[NSSplitViewController alloc] initWithNibName:nil bundle:nil];
        CHECK([svc isKindOfClass:[NSViewController class]], "is an NSViewController");
        CHECK(svc.splitViewItems.count == 0, "no items initially");

        NSViewController *side = [[NSViewController alloc] init];
        NSViewController *main = [[NSViewController alloc] init];
        NSSplitViewItem *sidebar = [NSSplitViewItem splitViewItemWithViewController:side];
        NSSplitViewItem *content = [NSSplitViewItem splitViewItemWithViewController:main];

        [svc addSplitViewItem:sidebar];
        [svc addSplitViewItem:content];
        CHECK(svc.splitViewItems.count == 2, "two items added");
        CHECK(side.parentViewController == svc, "sidebar vc added as child");
        CHECK(main.parentViewController == svc, "content vc added as child");
        CHECK(svc.childViewControllers.count == 2, "two child view controllers");
        CHECK([svc splitViewItemForViewController:main] == content, "splitViewItemForViewController finds content");

        /* insert at index */
        NSViewController *inspector = [[NSViewController alloc] init];
        NSSplitViewItem *insp = [NSSplitViewItem splitViewItemWithViewController:inspector];
        [svc insertSplitViewItem:insp atIndex:1];
        CHECK(svc.splitViewItems[1] == insp, "inserted at index 1");
        CHECK(svc.childViewControllers.count == 3, "child count grew");

        /* remove detaches child */
        [svc removeSplitViewItem:sidebar];
        CHECK(svc.splitViewItems.count == 2, "item removed");
        CHECK(side.parentViewController == nil, "removed item's vc detached");

        /* setSplitViewItems replaces */
        [svc setSplitViewItems:@[content]];
        CHECK(svc.splitViewItems.count == 1 && svc.splitViewItems[0] == content, "setSplitViewItems replaces");
        CHECK(inspector.parentViewController == nil, "old items detached by setSplitViewItems");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
