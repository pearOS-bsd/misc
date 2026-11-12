/* test_nsbrowser.m */
#import "../src/NSBrowser.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSBrowser *b = [[NSBrowser alloc] initWithFrame:NSMakeRect(0,0,400,200)];
        CHECK([b isKindOfClass:[NSControl class]], "is-a NSControl");

        /* measured defaults */
        CHECK(b.maxVisibleColumns == 0, "maxVisibleColumns 0 default");
        CHECK(b.minColumnWidth == 100.0, "minColumnWidth 100 default");
        CHECK(!b.hasHorizontalScroller, "hasHorizontalScroller NO default");
        CHECK(!b.allowsMultipleSelection, "allowsMultipleSelection NO default");
        CHECK(b.allowsEmptySelection, "allowsEmptySelection YES default");
        CHECK(!b.allowsBranchSelection, "allowsBranchSelection NO default");
        CHECK(b.separatesColumns, "separatesColumns YES default");
        CHECK(b.isTitled, "titled YES default");
        CHECK(!b.reusesColumns, "reusesColumns NO default");
        CHECK([b.pathSeparator isEqual:@"/"], "pathSeparator / default");
        CHECK(b.takesTitleFromPreviousColumn, "takesTitleFromPreviousColumn YES default");
        CHECK(b.lastColumn == -1 && b.selectedColumn == -1, "no columns/selection default");
        CHECK(b.numberOfVisibleColumns == 0, "no visible columns default");

        /* column model */
        [b loadColumnZero];
        CHECK(b.lastColumn == 0 && b.numberOfVisibleColumns == 1, "loadColumnZero loads column 0");
        [b addColumn]; [b addColumn];
        CHECK(b.lastColumn == 2 && b.numberOfVisibleColumns == 3, "addColumn advances lastColumn");
        [b selectRow:1 inColumn:2];
        CHECK(b.selectedColumn == 2, "selectRow:inColumn: tracks selected column");
        [b setLastColumn:1];
        CHECK(b.lastColumn == 1 && b.selectedColumn == 1, "setLastColumn truncates + clamps selection");
        [b selectRow:0 inColumn:5];
        CHECK(b.selectedColumn == 1, "selectRow in out-of-range column ignored");

        /* setters */
        b.allowsMultipleSelection = YES; CHECK(b.allowsMultipleSelection, "allowsMultipleSelection set");
        b.minColumnWidth = 150; CHECK(b.minColumnWidth == 150, "minColumnWidth set");
        b.pathSeparator = @":"; CHECK([b.pathSeparator isEqual:@":"], "pathSeparator set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
