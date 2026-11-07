/* test_nstablecolumn.m — NSTableColumn: identifier, width clamping, editable. */
#import "../src/NSTableColumn.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTableColumn *c = [[NSTableColumn alloc] initWithIdentifier:@"name"];
        CHECK([c.identifier isEqualToString:@"name"], "identifier set from init");
        CHECK(c.width == 100.0, "default width 100");

        c.width = 250.0;
        CHECK(c.width == 250.0, "width in range");
        c.width = 5000.0;
        CHECK(c.width == c.maxWidth, "width clamped to maxWidth");
        c.width = 1.0;
        CHECK(c.width == c.minWidth, "width clamped to minWidth");

        /* tightening minWidth bumps the current width */
        c.width = 50.0;
        c.minWidth = 80.0;
        CHECK(c.width == 80.0, "raising minWidth pushes width up");
        c.maxWidth = 70.0;
        CHECK(c.width == 70.0, "lowering maxWidth pulls width down");

        c.title = @"Name";
        CHECK([c.title isEqualToString:@"Name"], "title round-trips");
        c.editable = YES;
        CHECK(c.isEditable, "editable round-trips");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
