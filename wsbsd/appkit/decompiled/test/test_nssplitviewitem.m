/* test_nssplitviewitem.m — NSSplitViewItem wrapper. */
#import "../src/NSSplitViewItem.h"
#import "../src/NSViewController.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSViewController *vc = [[NSViewController alloc] init];
        NSSplitViewItem *item = [NSSplitViewItem splitViewItemWithViewController:vc];
        CHECK(item.viewController == vc, "viewController from factory");
        CHECK(!item.isCollapsed, "not collapsed by default");
        CHECK(item.canCollapse, "canCollapse default YES");
        CHECK(item.holdingPriority == 250.0, "default holding priority 250 (DefaultLow)");
        CHECK(item.minimumThickness == NSSplitViewItemUnspecifiedDimension, "min thickness unspecified");
        CHECK(item.maximumThickness == NSSplitViewItemUnspecifiedDimension, "max thickness unspecified");
        CHECK(item.behavior == NSSplitViewItemBehaviorDefault, "default behavior");

        item.collapsed = YES;
        item.canCollapse = NO;
        item.holdingPriority = 260.0;
        item.minimumThickness = 100;
        item.maximumThickness = 400;
        CHECK(item.isCollapsed, "collapsed set");
        CHECK(!item.canCollapse, "canCollapse set NO");
        CHECK(item.holdingPriority == 260.0, "holding priority set");
        CHECK(item.minimumThickness == 100 && item.maximumThickness == 400, "thickness bounds set");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
