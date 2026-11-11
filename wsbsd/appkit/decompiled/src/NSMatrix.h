/*
 * NSMatrix.h — 1:1 reimplementation (behavioral core) of AppKit's NSMatrix
 * (: NSControl), the grid-of-cells control (base for NSForm).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSMatrix_interface.txt. Real ivars: _cells (row-major), _numRows/
 * _numCols, _cellSize/_intercell, _selectedCell/_selectedRow/_selectedCol,
 * _cellClass/_protoCell, colours, and the packed _mFlags (mode/drawsBackground/…).
 *
 * Defaults MEASURED on this Mac: default init is 0×0, mode Radio(0),
 * allowsEmptySelection NO; the prototype/cellClass initializers fill the grid;
 * selectCellAtRow:column: updates selectedRow/selectedColumn/selectedCell.
 *
 * This core reproduces the cell-grid model (add/insert/remove rows & columns,
 * cellAtRow:column:, putCell:, makeCell), the selection model (radio = single),
 * and the value config. Cell layout/drawing, mouse/keyboard tracking, autosizing
 * and scrolling are TODO(stage2).
 */

#import "NSControl.h"

NS_ASSUME_NONNULL_BEGIN

@class NSCell, NSColor;

typedef NS_ENUM(NSUInteger, NSMatrixMode) {
    NSRadioModeMatrix     = 0,
    NSHighlightModeMatrix = 1,
    NSListModeMatrix      = 2,
    NSTrackModeMatrix     = 3,
};

@interface NSMatrix : NSControl

- (instancetype)initWithFrame:(NSRect)frame;
- (instancetype)initWithFrame:(NSRect)frame mode:(NSMatrixMode)mode prototype:(nullable NSCell *)cell numberOfRows:(NSInteger)rowsHigh numberOfColumns:(NSInteger)colsWide;
- (instancetype)initWithFrame:(NSRect)frame mode:(NSMatrixMode)mode cellClass:(nullable Class)factoryId numberOfRows:(NSInteger)rowsHigh numberOfColumns:(NSInteger)colsWide;

@property (assign) Class cellClass;
@property (nullable, copy) NSCell *prototype;
@property NSMatrixMode mode;
@property BOOL allowsEmptySelection;
@property (readonly, copy) NSArray *cells;
@property (nullable, readonly) NSCell *selectedCell;
@property (readonly, copy) NSArray<NSCell *> *selectedCells;
@property (readonly) NSInteger selectedRow;
@property (readonly) NSInteger selectedColumn;
@property (readonly) NSInteger numberOfRows;
@property (readonly) NSInteger numberOfColumns;
@property NSSize cellSize;
@property NSSize intercellSpacing;
@property (nullable, copy) NSColor *backgroundColor;
@property (nullable, copy) NSColor *cellBackgroundColor;
@property BOOL drawsBackground;
@property BOOL drawsCellBackground;
@property BOOL autosizesCells;

- (nullable NSCell *)cellAtRow:(NSInteger)row column:(NSInteger)col;
- (void)putCell:(NSCell *)newCell atRow:(NSInteger)row column:(NSInteger)col;
- (NSCell *)makeCellAtRow:(NSInteger)row column:(NSInteger)col;
- (void)addRow;
- (void)addColumn;
- (void)insertRow:(NSInteger)row;
- (void)insertColumn:(NSInteger)col;
- (void)removeRow:(NSInteger)row;
- (void)removeColumn:(NSInteger)col;
- (void)renewRows:(NSInteger)newRows columns:(NSInteger)newCols;

- (void)selectCellAtRow:(NSInteger)row column:(NSInteger)col;
- (BOOL)selectCellWithTag:(NSInteger)tag;
- (void)deselectAllCells;
- (void)deselectSelectedCell;
- (nullable NSCell *)cellWithTag:(NSInteger)tag;
- (BOOL)getRow:(nullable NSInteger *)row column:(nullable NSInteger *)col ofCell:(NSCell *)cell;

@end

NS_ASSUME_NONNULL_END
