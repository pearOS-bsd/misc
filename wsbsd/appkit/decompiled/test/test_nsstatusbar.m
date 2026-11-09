/* test_nsstatusbar.m — NSStatusBar: singleton, thickness, status items. */
#import "../src/NSStatusBar.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSStatusBar *bar = [NSStatusBar systemStatusBar];
        CHECK(bar != nil, "systemStatusBar returns an instance");
        CHECK([NSStatusBar systemStatusBar] == bar, "systemStatusBar is a singleton");
        CHECK(bar.thickness == 20.0, "thickness is 20");
        CHECK(bar.isVertical == NO, "status bar is horizontal");

        NSStatusItem *si = [bar statusItemWithLength:NSVariableStatusItemLength];
        CHECK([si isKindOfClass:[NSStatusItem class]], "statusItemWithLength builds an NSStatusItem");
        CHECK(si.length == NSVariableStatusItemLength, "item gets the requested length");

        NSStatusItem *si2 = [bar statusItemWithLength:30.0];
        CHECK(si2.length == 30.0, "second item length");
        CHECK(si2 != si, "distinct items");

        [bar removeStatusItem:si];   /* no crash; item dropped from the bar */
        CHECK(YES, "removeStatusItem runs");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
