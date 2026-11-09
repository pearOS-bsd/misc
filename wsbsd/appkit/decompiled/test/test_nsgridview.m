/* test_nsgridview.m — NSGridView matrix bookkeeping. */
#import "../src/NSGridView.h"
#import "../src/NSView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

static NSView *mk(void) { return [[NSView alloc] initWithFrame:CGRectMake(0,0,20,20)]; }

int main(void)
{
    @autoreleasepool {
        NSGridView *g = [[NSGridView alloc] initWithFrame:CGRectMake(0,0,200,200)];
        CHECK([g isKindOfClass:[NSView class]], "NSGridView is an NSView");
        CHECK(g.numberOfRows == 0 && g.numberOfColumns == 0, "empty grid");
        CHECK(g.xPlacement == NSGridCellPlacementInherited, "default xPlacement Inherited");

        NSView *a = mk(), *b = mk(), *c = mk();
        NSGridRow *row0 = [g addRowWithViews:@[a, b, c]];
        CHECK(g.numberOfRows == 1, "one row");
        CHECK(g.numberOfColumns == 3, "three columns created to match the row");
        CHECK(row0.numberOfCells == 3, "row has three cells");

        /* cells carry their content views and back-links */
        NSGridCell *cell01 = [g cellAtColumnIndex:1 rowIndex:0];
        CHECK(cell01.contentView == b, "cell (col1,row0) holds view b");
        CHECK(cell01.row == row0, "cell row back-link");
        CHECK(cell01.column == [g columnAtIndex:1], "cell column back-link");

        /* second row reuses the 3 columns */
        [g addRowWithViews:@[mk(), mk(), mk()]];
        CHECK(g.numberOfRows == 2, "two rows");
        CHECK(g.numberOfColumns == 3, "still three columns");

        /* a shorter row grows nothing; a longer row grows columns */
        [g addRowWithViews:@[mk(), mk(), mk(), mk()]];
        CHECK(g.numberOfColumns == 4, "longer row grows columns to 4");

        /* addColumnWithViews appends a cell to each existing row */
        NSInteger rowsBefore = g.numberOfRows;
        [g addColumnWithViews:@[mk(), mk(), mk()]];
        CHECK(g.numberOfColumns == 5, "column added");
        CHECK(g.numberOfRows == rowsBefore, "rows unchanged (had >= views)");
        CHECK([g rowAtIndex:0].numberOfCells == 5, "row 0 grew a cell for the new column");

        /* out-of-range raises */
        BOOL raised = NO;
        @try { [g cellAtColumnIndex:0 rowIndex:99]; } @catch (NSException *e) { raised = YES; }
        CHECK(raised, "out-of-range row raises");

        /* spacing settable */
        g.rowSpacing = 6.0; g.columnSpacing = 8.0;
        CHECK(g.rowSpacing == 6.0 && g.columnSpacing == 8.0, "spacing settable");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
