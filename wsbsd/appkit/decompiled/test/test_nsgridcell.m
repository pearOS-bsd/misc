/* test_nsgridcell.m — NSGridCell value fields. */
#import "../src/NSGridCell.h"
#import "../src/NSView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSGridCell *cell = [[NSGridCell alloc] init];
        CHECK(cell.xPlacement == NSGridCellPlacementInherited, "xPlacement default Inherited");
        CHECK(cell.yPlacement == NSGridCellPlacementInherited, "yPlacement default Inherited");
        CHECK(cell.rowAlignment == NSGridRowAlignmentInherited, "rowAlignment default Inherited");
        CHECK(cell.contentView == nil, "no content view by default");
        CHECK(cell.row == nil && cell.column == nil, "no row/column by default");

        NSView *v = [[NSView alloc] initWithFrame:CGRectMake(0,0,50,20)];
        cell.contentView = v;
        CHECK(cell.contentView == v, "content view set");

        cell.xPlacement = NSGridCellPlacementCenter;
        cell.yPlacement = NSGridCellPlacementFill;
        cell.rowAlignment = NSGridRowAlignmentFirstBaseline;
        CHECK(cell.xPlacement == NSGridCellPlacementCenter, "xPlacement set");
        CHECK(cell.yPlacement == NSGridCellPlacementFill, "yPlacement set");
        CHECK(cell.rowAlignment == NSGridRowAlignmentFirstBaseline, "rowAlignment set");

        /* grid glue sets row/column (weak) */
        id row = [NSObject new];
        id col = [NSObject new];
        [cell _setRow:row];
        [cell _setColumn:col];
        CHECK(cell.row == row, "row back-link set");
        CHECK(cell.column == col, "column back-link set");

        /* Top/Leading and Bottom/Trailing share raw values (AppKit axis reuse) */
        CHECK(NSGridCellPlacementTop == NSGridCellPlacementLeading, "Top == Leading raw value");
        CHECK(NSGridCellPlacementBottom == NSGridCellPlacementTrailing, "Bottom == Trailing raw value");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
