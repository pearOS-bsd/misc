/* test_nsgridrow.m — NSGridRow value fields + owned cells. */
#import "../src/NSGridRow.h"
#import "../src/NSGridCell.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSGridRow *row = [[NSGridRow alloc] init];
        CHECK(row.yPlacement == NSGridCellPlacementInherited, "yPlacement default Inherited");
        CHECK(row.rowAlignment == NSGridRowAlignmentInherited, "rowAlignment default Inherited");
        CHECK(row.height == NSGridViewSizeForContent, "height default size-for-content");
        CHECK(row.numberOfCells == 0, "no cells initially");
        CHECK(!row.isHidden && row.gridView == nil, "defaults: not hidden, no grid");

        row.yPlacement = NSGridCellPlacementCenter;
        row.rowAlignment = NSGridRowAlignmentLastBaseline;
        row.height = 30.0;
        row.topPadding = 2.0;
        row.bottomPadding = 3.0;
        row.hidden = YES;
        CHECK(row.yPlacement == NSGridCellPlacementCenter, "yPlacement set");
        CHECK(row.rowAlignment == NSGridRowAlignmentLastBaseline, "rowAlignment set");
        CHECK(row.height == 30.0 && row.topPadding == 2.0 && row.bottomPadding == 3.0, "metrics set");
        CHECK(row.isHidden, "hidden set");

        /* owned cells */
        NSGridCell *c0 = [[NSGridCell alloc] init];
        NSGridCell *c1 = [[NSGridCell alloc] init];
        [row _addCell:c0];
        [row _addCell:c1];
        CHECK(row.numberOfCells == 2, "two cells added");
        CHECK([row cellAtIndex:0] == c0 && [row cellAtIndex:1] == c1, "cellAtIndex returns cells in order");

        BOOL raised = NO;
        @try { [row cellAtIndex:5]; } @catch (NSException *e) { raised = YES; }
        CHECK(raised, "out-of-range cell index raises");

        id grid = [NSObject new];
        [row _setGridView:grid];
        CHECK(row.gridView == grid, "grid view back-link set");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
