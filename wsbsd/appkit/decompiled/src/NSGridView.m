/*
 * NSGridView.m — 1:1 (core). See NSGridView.h for the interface evidence.
 *
 * Keeps parallel _rows (NSGridRow, each owning its cells) and _columns
 * (NSGridColumn). addRowWithViews: makes a row with one NSGridCell per view and
 * grows _columns so there is a column per cell; addColumnWithViews: makes a
 * column and appends a cell to each row (growing rows as needed). Each cell's
 * row/column back-links are wired. cellAtColumnIndex:rowIndex: indexes the
 * matrix. rowSpacing/columnSpacing default to the size-for-content sentinel
 * (standard spacing); resolving that to points, and all frame layout, is stage2.
 */
#import "NSGridView.h"

@implementation NSGridView {
    NSMutableArray<NSGridRow *> *_rows;
    NSMutableArray<NSGridColumn *> *_columns;
    NSGridCellPlacement _xPlacement;
    NSGridCellPlacement _yPlacement;
    NSGridRowAlignment _rowAlignment;
    CGFloat _rowSpacing;
    CGFloat _colSpacing;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _rows = [NSMutableArray array];
        _columns = [NSMutableArray array];
        _xPlacement = NSGridCellPlacementInherited;
        _yPlacement = NSGridCellPlacementInherited;
        _rowAlignment = NSGridRowAlignmentInherited;
        _rowSpacing = NSGridViewSizeForContent;   /* standard spacing */
        _colSpacing = NSGridViewSizeForContent;
    }
    return self;
}

- (NSInteger)numberOfRows { return (NSInteger)_rows.count; }
- (NSInteger)numberOfColumns { return (NSInteger)_columns.count; }

- (NSGridRow *)rowAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_rows.count)
        [NSException raise:NSRangeException format:@"row index %ld out of range", (long)index];
    return _rows[index];
}
- (NSGridColumn *)columnAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_columns.count)
        [NSException raise:NSRangeException format:@"column index %ld out of range", (long)index];
    return _columns[index];
}
- (NSGridCell *)cellAtColumnIndex:(NSInteger)columnIndex rowIndex:(NSInteger)rowIndex
{
    return [[self rowAtIndex:rowIndex] cellAtIndex:columnIndex];
}

- (void)_ensureColumns:(NSInteger)count
{
    while ((NSInteger)_columns.count < count) {
        NSGridColumn *c = [[NSGridColumn alloc] init];
        [c _setGridView:self];
        [_columns addObject:c];
    }
}

/* Keep the cell matrix rectangular: every row has one cell per column, each
 * wired to its row and column. Missing cells are created empty. */
- (void)_normalize
{
    for (NSGridRow *row in _rows) {
        while (row.numberOfCells < (NSInteger)_columns.count) {
            NSGridCell *cell = [[NSGridCell alloc] init];
            [cell _setRow:row];
            [cell _setColumn:_columns[row.numberOfCells]];
            [row _addCell:cell];
        }
    }
}

- (NSGridRow *)addRowWithViews:(NSArray<NSView *> *)views
{
    [self _ensureColumns:(NSInteger)views.count];
    NSGridRow *row = [[NSGridRow alloc] init];
    [row _setGridView:self];
    for (NSUInteger i = 0; i < views.count; i++) {
        NSGridCell *cell = [[NSGridCell alloc] init];
        id v = views[i];
        if (v != (id)[NSNull null]) cell.contentView = v;
        [cell _setRow:row];
        [cell _setColumn:_columns[i]];
        [row _addCell:cell];
    }
    [_rows addObject:row];
    [self _normalize];   /* backfill shorter existing rows / this row */
    return row;
}

- (NSGridColumn *)addColumnWithViews:(NSArray<NSView *> *)views
{
    NSGridColumn *col = [[NSGridColumn alloc] init];
    [col _setGridView:self];
    [_columns addObject:col];
    /* grow rows so every row has a cell in the new column */
    while (_rows.count < views.count) {
        NSGridRow *r = [[NSGridRow alloc] init];
        [r _setGridView:self];
        [_rows addObject:r];
    }
    [self _normalize];   /* gives every row a cell for the new (and any) column */
    for (NSUInteger i = 0; i < views.count && i < _rows.count; i++) {
        if (views[i] != (id)[NSNull null])
            [[_rows[i] cellAtIndex:(_columns.count - 1)] setContentView:views[i]];
    }
    return col;
}

- (NSGridCellPlacement)xPlacement { return _xPlacement; }
- (void)setXPlacement:(NSGridCellPlacement)v { _xPlacement = v; }
- (NSGridCellPlacement)yPlacement { return _yPlacement; }
- (void)setYPlacement:(NSGridCellPlacement)v { _yPlacement = v; }
- (NSGridRowAlignment)rowAlignment { return _rowAlignment; }
- (void)setRowAlignment:(NSGridRowAlignment)v { _rowAlignment = v; }
- (CGFloat)rowSpacing { return _rowSpacing; }
- (void)setRowSpacing:(CGFloat)v { _rowSpacing = v; }
- (CGFloat)columnSpacing { return _colSpacing; }
- (void)setColumnSpacing:(CGFloat)v { _colSpacing = v; }

@end
