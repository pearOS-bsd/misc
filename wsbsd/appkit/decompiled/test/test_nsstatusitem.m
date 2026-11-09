/* test_nsstatusitem.m — NSStatusItem: length, menu, visible. */
#import "../src/NSStatusItem.h"
#import "../src/NSMenu.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSStatusItem *si = [[NSStatusItem alloc] init];
        CHECK(si.length == NSVariableStatusItemLength, "default length variable (-1)");
        CHECK(si.isVisible == YES, "visible by default");

        si.length = 28.0;
        CHECK(si.length == 28.0, "fixed length round-trips");
        si.length = NSSquareStatusItemLength;
        CHECK(si.length == NSSquareStatusItemLength, "square length (-2) round-trips");

        NSMenu *m = [[NSMenu alloc] initWithTitle:@""];
        si.menu = m;
        CHECK(si.menu == m, "menu round-trips");

        si.visible = NO;
        CHECK(!si.isVisible, "visible round-trips");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
