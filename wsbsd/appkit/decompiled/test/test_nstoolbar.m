/* test_nstoolbar.m — NSToolbar: identifier, displayMode bits, visible, customization. */
#import "../src/NSToolbar.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSToolbar *tb = [[NSToolbar alloc] initWithIdentifier:@"main"];
        CHECK([tb.identifier isEqualToString:@"main"], "identifier from init");
        CHECK(tb.displayMode == NSToolbarDisplayModeDefault, "default displayMode");
        CHECK(tb.isVisible == YES, "visible by default");

        tb.displayMode = NSToolbarDisplayModeIconOnly;
        CHECK(tb.displayMode == NSToolbarDisplayModeIconOnly, "displayMode round-trips");
        tb.displayMode = NSToolbarDisplayModeLabelOnly;
        CHECK(tb.displayMode == NSToolbarDisplayModeLabelOnly, "displayMode updates");

        tb.allowsUserCustomization = YES;
        CHECK(tb.allowsUserCustomization, "allowsUserCustomization round-trips");
        /* displayMode (bits 22-23) and customization (bit 0) are independent */
        CHECK(tb.displayMode == NSToolbarDisplayModeLabelOnly, "flags independent");

        tb.visible = NO;
        CHECK(!tb.isVisible, "visible round-trips");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
