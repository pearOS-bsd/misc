/* test_nstoolbaritem.m — NSToolbarItem core. */
#import "../src/NSToolbarItem.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSToolbarItem *it = [[NSToolbarItem alloc] initWithItemIdentifier:@"save"];
        CHECK([it.itemIdentifier isEqualToString:@"save"], "itemIdentifier from init");
        CHECK([it.label isEqualToString:@""], "label defaults empty (nil -> \"\")");
        CHECK(it.isEnabled == YES, "enabled by default");

        it.label = @"Save";
        CHECK([it.label isEqualToString:@"Save"], "label round-trips");
        it.label = nil;
        CHECK([it.label isEqualToString:@""], "nil label reads back as empty string");

        it.paletteLabel = @"Save Document";
        CHECK([it.paletteLabel isEqualToString:@"Save Document"], "paletteLabel round-trips");
        it.toolTip = @"Save the file";
        CHECK([it.toolTip isEqualToString:@"Save the file"], "toolTip round-trips");

        it.tag = 42;
        CHECK(it.tag == 42, "tag round-trips");
        it.enabled = NO;
        CHECK(!it.isEnabled, "enabled round-trips");

        /* view-based item */
        CHECK(it.view == nil, "no view by default");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
