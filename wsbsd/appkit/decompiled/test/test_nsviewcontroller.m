/* test_nsviewcontroller.m — NSViewController: lazy view + child tree. */
#import "../src/NSViewController.h"
#import "../src/NSView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSViewController *vc = [[NSViewController alloc] initWithNibName:nil bundle:nil];
        vc.title = @"Main";
        vc.representedObject = @42;
        CHECK([vc.title isEqualToString:@"Main"], "title set");
        CHECK([vc.representedObject isEqual:@42], "representedObject set");

        /* view is lazy */
        CHECK(!vc.isViewLoaded, "view not loaded before access");
        NSView *v = vc.view;
        CHECK(v != nil, "view lazily created");
        CHECK(vc.isViewLoaded, "isViewLoaded true after access");
        CHECK(vc.view == v, "view is stable across calls");

        /* explicit setView */
        NSViewController *vc2 = [[NSViewController alloc] init];
        NSView *custom = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        vc2.view = custom;
        CHECK(vc2.isViewLoaded, "setView marks loaded");
        CHECK(vc2.view == custom, "custom view used (loadView not called)");

        /* child controllers */
        NSViewController *child1 = [[NSViewController alloc] init];
        NSViewController *child2 = [[NSViewController alloc] init];
        [vc addChildViewController:child1];
        [vc addChildViewController:child2];
        CHECK(vc.childViewControllers.count == 2, "two children added");
        CHECK(child1.parentViewController == vc, "child1 parent set");
        CHECK(child2.parentViewController == vc, "child2 parent set");
        CHECK(vc.childViewControllers[0] == child1, "child order preserved");

        /* insert at index */
        NSViewController *child0 = [[NSViewController alloc] init];
        [vc insertChildViewController:child0 atIndex:0];
        CHECK(vc.childViewControllers[0] == child0, "inserted at index 0");
        CHECK(vc.childViewControllers.count == 3, "insert grows children");

        /* reparenting: adding child1 to vc2 removes it from vc */
        [vc2 addChildViewController:child1];
        CHECK(child1.parentViewController == vc2, "child1 reparented to vc2");
        CHECK(![vc.childViewControllers containsObject:child1], "child1 removed from old parent");
        CHECK(vc.childViewControllers.count == 2, "old parent lost a child");

        /* removeFromParent */
        [child2 removeFromParentViewController];
        CHECK(child2.parentViewController == nil, "removed child has no parent");
        CHECK(vc.childViewControllers.count == 1, "parent lost the child");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
