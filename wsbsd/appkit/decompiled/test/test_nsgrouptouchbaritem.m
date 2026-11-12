/* test_nsgrouptouchbaritem.m */
#import "../src/NSGroupTouchBarItem.h"
#import "../src/NSTouchBar.h"
#import "../src/NSCustomTouchBarItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSGroupTouchBarItem *g = [[NSGroupTouchBarItem alloc] initWithIdentifier:@"grp"];
        CHECK([g isKindOfClass:[NSTouchBarItem class]], "is NSTouchBarItem");
        CHECK(g.groupTouchBar != nil, "groupTouchBar auto-created");
        CHECK(g.groupUserInterfaceLayoutDirection == NSUserInterfaceLayoutDirectionLeftToRight, "layout dir LTR default");
        CHECK(!g.prefersEqualWidths, "prefersEqualWidths NO default");
        CHECK(g.preferredItemWidth == -1, "preferredItemWidth -1 default");
        CHECK(!g.groupHasAlertStyle, "not alert style by default");

        /* setters */
        g.groupUserInterfaceLayoutDirection = NSUserInterfaceLayoutDirectionRightToLeft;
        CHECK(g.groupUserInterfaceLayoutDirection == NSUserInterfaceLayoutDirectionRightToLeft, "layout dir set");
        g.prefersEqualWidths = YES; g.preferredItemWidth = 40;
        CHECK(g.prefersEqualWidths && g.preferredItemWidth == 40, "equal-widths + preferred width set");
        g.customizationLabel = @"Tools";
        CHECK([g.customizationLabel isEqual:@"Tools"], "customizationLabel set");

        /* groupItemWithIdentifier:items: exposes item identifiers on the nested bar */
        NSCustomTouchBarItem *a = [[NSCustomTouchBarItem alloc] initWithIdentifier:@"a"];
        NSCustomTouchBarItem *b = [[NSCustomTouchBarItem alloc] initWithIdentifier:@"b"];
        NSGroupTouchBarItem *g2 = [NSGroupTouchBarItem groupItemWithIdentifier:@"grp2" items:@[a, b]];
        CHECK(g2.groupTouchBar.defaultItemIdentifiers.count == 2, "group touch bar lists the two item ids");
        CHECK([g2.groupTouchBar.defaultItemIdentifiers[0] isEqual:@"a"], "first id is 'a'");

        /* alert style factory */
        NSGroupTouchBarItem *ga = [NSGroupTouchBarItem alertStyleGroupItemWithIdentifier:@"alert"];
        CHECK(ga.groupHasAlertStyle, "alertStyleGroupItem has alert style");

        /* prioritizedCompressionOptions copy */
        id opt = [NSObject new];
        g.prioritizedCompressionOptions = @[(id)opt];
        CHECK(g.prioritizedCompressionOptions.count == 1, "prioritizedCompressionOptions set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
