/* test_nsoutlineview.m — NSOutlineView (: NSTableView) core. */
#import "../src/NSOutlineView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSOutlineView *ov = [[NSOutlineView alloc] initWithFrame:CGRectMake(0, 0, 400, 300)];
        CHECK([ov isKindOfClass:[NSTableView class]], "NSOutlineView is an NSTableView");

        /* inherits column management from NSTableView */
        NSTableColumn *c = [[NSTableColumn alloc] initWithIdentifier:@"tree"];
        [ov addTableColumn:c];
        CHECK(ov.numberOfColumns == 1, "inherits addTableColumn");

        CHECK(ov.indentationPerLevel == 16.0, "default indentationPerLevel 16");
        ov.indentationPerLevel = 24.0;
        CHECK(ov.indentationPerLevel == 24.0, "indentationPerLevel round-trips");
        ov.indentationPerLevel = -5.0;
        CHECK(ov.indentationPerLevel == 0.0, "indentationPerLevel clamps >= 0");
        ov.indentationPerLevel = 20.7;
        CHECK(ov.indentationPerLevel == 20.0, "indentationPerLevel stored as integer (truncates)");

        ov.outlineTableColumn = c;
        CHECK(ov.outlineTableColumn == c, "outlineTableColumn round-trips");

        CHECK(ov.autoresizesOutlineColumn == YES, "autoresizesOutlineColumn defaults YES");
        ov.autoresizesOutlineColumn = NO;
        CHECK(!ov.autoresizesOutlineColumn, "autoresizesOutlineColumn round-trips");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
