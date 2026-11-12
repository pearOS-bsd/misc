/* test_nstrackingseparatortoolbaritem.m */
#import "../src/NSTrackingSeparatorToolbarItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* plain init: measured defaults */
        NSTrackingSeparatorToolbarItem *p = [[NSTrackingSeparatorToolbarItem alloc] initWithItemIdentifier:@"s"];
        CHECK([p isKindOfClass:[NSToolbarItem class]], "is NSToolbarItem");
        CHECK(p.splitView == nil && p.dividerIndex == 0, "plain init: nil splitView, index 0");

        /* factory stores splitView + dividerIndex */
        id sv = [NSObject new]; /* stand-in NSSplitView */
        NSTrackingSeparatorToolbarItem *t =
            [NSTrackingSeparatorToolbarItem trackingSeparatorToolbarItemWithIdentifier:@"sep"
                                                                            splitView:(id)sv
                                                                         dividerIndex:2];
        CHECK([t.itemIdentifier isEqual:@"sep"], "factory identifier");
        CHECK((id)t.splitView == sv, "factory stores splitView");
        CHECK(t.dividerIndex == 2, "factory stores dividerIndex");

        /* setters */
        id sv2 = [NSObject new];
        t.splitView = (id)sv2; t.dividerIndex = 5;
        CHECK((id)t.splitView == sv2 && t.dividerIndex == 5, "setters");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
