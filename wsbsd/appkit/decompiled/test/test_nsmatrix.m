/* test_nsmatrix.m — behaviour checks for NSMatrix cell-grid + selection core */
#import "../src/NSMatrix.h"
#import "../src/NSCell.h"
#import "../src/NSActionCell.h"
#import "../src/NSApplication.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];

        /* default init: empty radio matrix */
        NSMatrix *d = [[NSMatrix alloc] initWithFrame:NSMakeRect(0,0,50,50)];
        CHECK([d isKindOfClass:[NSControl class]], "is an NSControl");
        CHECK(d.numberOfRows == 0 && d.numberOfColumns == 0, "default 0x0");
        CHECK(d.mode == NSRadioModeMatrix, "default mode Radio");
        CHECK(!d.allowsEmptySelection, "default allowsEmptySelection NO");
        CHECK(NSRadioModeMatrix==0 && NSHighlightModeMatrix==1 && NSListModeMatrix==2 && NSTrackModeMatrix==3, "mode enum values");

        /* prototype grid */
        NSActionCell *proto = [[NSActionCell alloc] init];
        NSMatrix *m = [[NSMatrix alloc] initWithFrame:NSMakeRect(0,0,100,100) mode:NSRadioModeMatrix prototype:proto numberOfRows:2 numberOfColumns:3];
        CHECK(m.numberOfRows == 2 && m.numberOfColumns == 3, "2x3 grid");
        CHECK(m.cells.count == 6, "6 cells");
        CHECK([m cellAtRow:1 column:2] != nil, "cellAtRow:1 column:2 exists");
        CHECK([m cellAtRow:2 column:0] == nil, "out-of-range cell nil");
        CHECK([[m cellAtRow:0 column:0] isKindOfClass:[NSActionCell class]], "cells are prototype's class");

        /* radio selection is single + updates indices */
        [m selectCellAtRow:0 column:1];
        CHECK(m.selectedRow == 0 && m.selectedColumn == 1 && m.selectedCell == [m cellAtRow:0 column:1], "select sets indices+cell");
        CHECK([m cellAtRow:0 column:1].state == NSControlStateValueOn, "selected cell state On");
        [m selectCellAtRow:1 column:2];
        CHECK(m.selectedRow == 1 && m.selectedColumn == 2, "re-select moves selection");
        CHECK([m cellAtRow:0 column:1].state == NSControlStateValueOff, "radio deselects previous");
        CHECK(m.selectedCells.count == 1, "one selected cell in radio");

        /* cellWithTag / selectCellWithTag */
        [[m cellAtRow:1 column:0] setTag:77];
        CHECK([m cellWithTag:77] == [m cellAtRow:1 column:0], "cellWithTag finds the cell");
        CHECK([m selectCellWithTag:77] && m.selectedRow == 1 && m.selectedColumn == 0, "selectCellWithTag selects it");

        /* getRow:column:ofCell: */
        NSInteger r = -1, c = -1;
        CHECK([m getRow:&r column:&c ofCell:[m cellAtRow:1 column:0]] && r == 1 && c == 0, "getRow:column:ofCell:");

        /* add/remove rows & columns */
        [m addRow];
        CHECK(m.numberOfRows == 3 && m.cells.count == 9, "addRow grows to 3x3");
        [m addColumn];
        CHECK(m.numberOfColumns == 4 && m.cells.count == 12, "addColumn grows to 3x4");
        [m removeRow:0];
        CHECK(m.numberOfRows == 2 && m.cells.count == 8, "removeRow shrinks");
        [m removeColumn:0];
        CHECK(m.numberOfColumns == 3 && m.cells.count == 6, "removeColumn shrinks");

        /* radio mode keeps a selection (deselectAllCells no-op) */
        [m selectCellAtRow:0 column:0];
        [m deselectAllCells];
        CHECK(m.selectedCell != nil, "radio deselectAllCells keeps selection");

        /* allowsEmptySelection lets it clear */
        m.allowsEmptySelection = YES;
        [m deselectAllCells];
        CHECK(m.selectedCell == nil && m.selectedRow == -1, "allowsEmptySelection clears selection");

        /* putCell replaces at position */
        NSActionCell *replacement = [[NSActionCell alloc] init];
        [m putCell:replacement atRow:0 column:0];
        CHECK([m cellAtRow:0 column:0] == replacement, "putCell replaces");

        /* cellClass path */
        NSMatrix *cm = [[NSMatrix alloc] initWithFrame:NSZeroRect mode:NSListModeMatrix cellClass:[NSActionCell class] numberOfRows:1 numberOfColumns:2];
        CHECK(cm.mode == NSListModeMatrix && cm.cells.count == 2, "cellClass init fills grid");
        CHECK(cm.cellClass == [NSActionCell class], "cellClass stored");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
