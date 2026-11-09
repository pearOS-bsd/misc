/* test_nsmenuitembadge.m — NSMenuItemBadge. */
#import "../src/NSMenuItemBadge.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSMenuItemBadge *count = [[NSMenuItemBadge alloc] initWithCount:5];
        CHECK(count.itemCount == 5, "count stored");
        CHECK(count.type == NSMenuItemBadgeTypeNone, "plain count has type None");
        CHECK([count.stringValue isEqualToString:@"5"], "stringValue is the count");
        CHECK(!count.isEmpty, "non-zero count not empty");

        NSMenuItemBadge *zero = [[NSMenuItemBadge alloc] initWithCount:0];
        CHECK(zero.isEmpty, "zero count is empty");

        NSMenuItemBadge *str = [[NSMenuItemBadge alloc] initWithString:@"NEW"];
        CHECK([str.stringValue isEqualToString:@"NEW"], "custom string value");
        CHECK(!str.isEmpty, "custom string not empty");

        NSMenuItemBadge *up = [NSMenuItemBadge updatesWithCount:3];
        CHECK(up.type == NSMenuItemBadgeTypeUpdates && up.itemCount == 3, "updates factory");
        NSMenuItemBadge *ni = [NSMenuItemBadge newItemsWithCount:2];
        CHECK(ni.type == NSMenuItemBadgeTypeNewItems, "new-items factory");
        NSMenuItemBadge *al = [NSMenuItemBadge alertsWithCount:1];
        CHECK(al.type == NSMenuItemBadgeTypeAlerts && [al.stringValue isEqualToString:@"1"], "alerts factory");

        /* copy */
        NSMenuItemBadge *c = [up copy];
        CHECK(c.type == NSMenuItemBadgeTypeUpdates && c.itemCount == 3, "copy carries type+count");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
