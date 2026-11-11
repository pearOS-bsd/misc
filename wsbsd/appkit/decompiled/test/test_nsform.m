/* test_nsform.m — behaviour checks for NSForm core */
#import "../src/NSForm.h"
#import "../src/NSApplication.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSForm *f = [[NSForm alloc] initWithFrame:NSMakeRect(0,0,200,100)];
        CHECK([f isKindOfClass:[NSMatrix class]], "is an NSMatrix");
        CHECK(f.cellClass == [NSFormCell class], "cellClass is NSFormCell");
        CHECK(f.numberOfRows == 0, "starts empty");

        /* addEntry appends titled rows */
        NSFormCell *e0 = [f addEntry:@"Name:"];
        NSFormCell *e1 = [f addEntry:@"Email:"];
        CHECK(f.numberOfRows == 2 && f.numberOfColumns == 1, "two entries, single column");
        CHECK([e0 isKindOfClass:[NSFormCell class]], "addEntry returns an NSFormCell");
        CHECK([e0.title isEqual:@"Name:"] && [e1.title isEqual:@"Email:"], "entry titles set");
        CHECK([f cellAtIndex:0] == e0 && [f cellAtIndex:1] == e1, "cellAtIndex returns the entries");

        /* insertEntry at index */
        NSFormCell *mid = [f insertEntry:@"Phone:" atIndex:1];
        CHECK(f.numberOfRows == 3 && [[[f cellAtIndex:1] title] isEqual:@"Phone:"], "insertEntry at index");
        CHECK([f cellAtIndex:1] == mid, "inserted cell at index 1");

        /* tags + indexOfCellWithTag / indexOfSelectedItem */
        [e1 setTag:9];
        CHECK([f indexOfCellWithTag:9] == 2, "indexOfCellWithTag finds Email: at row 2");
        CHECK([f indexOfCellWithTag:999] == -1, "unknown tag -> -1");
        [f selectCellAtRow:2 column:0];
        CHECK(f.indexOfSelectedItem == 2, "indexOfSelectedItem == selectedRow");

        /* bulk title setters fan out */
        [f setTitleAlignment:NSTextAlignmentLeft];
        CHECK([f cellAtIndex:0].titleAlignment == NSTextAlignmentLeft
              && [f cellAtIndex:2].titleAlignment == NSTextAlignmentLeft, "setTitleAlignment fans out to all cells");
        [f setBezeled:YES];
        CHECK([f cellAtIndex:0].isBezeled && [f cellAtIndex:1].isBezeled, "setBezeled fans out");

        /* removeEntryAtIndex */
        [f removeEntryAtIndex:0];
        CHECK(f.numberOfRows == 2 && [[[f cellAtIndex:0] title] isEqual:@"Phone:"], "removeEntryAtIndex drops first");

        /* setEntryWidth adjusts cellSize width */
        [f setEntryWidth:150];
        CHECK(f.cellSize.width == 150, "setEntryWidth sets cellSize width");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
