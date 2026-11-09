/* test_nsgridcolumn.m — NSGridColumn value fields. */
#import "../src/NSGridColumn.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSGridColumn *col = [[NSGridColumn alloc] init];
        CHECK(col.xPlacement == NSGridCellPlacementInherited, "xPlacement default Inherited");
        CHECK(col.width == NSGridViewSizeForContent, "width default is size-for-content sentinel");
        CHECK(col.leadingPadding == 0 && col.trailingPadding == 0, "padding default 0");
        CHECK(!col.isHidden, "not hidden by default");
        CHECK(col.gridView == nil, "no grid view by default");

        col.width = 120.0;
        col.xPlacement = NSGridCellPlacementTrailing;
        col.leadingPadding = 4.0;
        col.trailingPadding = 8.0;
        col.hidden = YES;
        CHECK(col.width == 120.0, "width set");
        CHECK(col.xPlacement == NSGridCellPlacementTrailing, "xPlacement set");
        CHECK(col.leadingPadding == 4.0 && col.trailingPadding == 8.0, "padding set");
        CHECK(col.isHidden, "hidden set");

        id grid = [NSObject new];
        [col _setGridView:grid];
        CHECK(col.gridView == grid, "grid view back-link set");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
