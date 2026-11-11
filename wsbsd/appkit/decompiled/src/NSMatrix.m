/*
 * NSMatrix.m — behavioral-1:1 cell-grid + selection core. See NSMatrix.h.
 */

#import "NSMatrix.h"
#import "NSCell.h"
#import "NSActionCell.h"

@implementation NSMatrix {
    NSMutableArray *_cells;        /* row-major, _numRows * _numCols */
    NSInteger _numRows, _numCols;
    Class _cellClass;
    NSCell *_prototype;
    NSMatrixMode _mode;
    BOOL _allowsEmptySelection;
    NSCell *_selectedCell;
    NSInteger _selectedRow, _selectedCol;
    NSSize _cellSize, _intercellSpacing;
    NSColor *_backgroundColor, *_cellBackgroundColor;
    BOOL _drawsBackground, _drawsCellBackground, _autosizesCells;
}

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _cells = [NSMutableArray array];
        _numRows = 0; _numCols = 0;
        _cellClass = [NSActionCell class];
        _mode = NSRadioModeMatrix;
        _allowsEmptySelection = NO;
        _selectedRow = -1; _selectedCol = -1;
        _cellSize = NSMakeSize(100, 17);
        _intercellSpacing = NSMakeSize(1, 4);
        _drawsBackground = YES; _drawsCellBackground = NO; _autosizesCells = YES;
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frame mode:(NSMatrixMode)mode cellClass:(Class)factoryId numberOfRows:(NSInteger)rows numberOfColumns:(NSInteger)cols
{
    self = [self initWithFrame:frame];
    if (self) {
        _mode = mode;
        _cellClass = factoryId ?: [NSActionCell class];
        [self renewRows:rows columns:cols];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frame mode:(NSMatrixMode)mode prototype:(NSCell *)cell numberOfRows:(NSInteger)rows numberOfColumns:(NSInteger)cols
{
    self = [self initWithFrame:frame];
    if (self) {
        _mode = mode;
        _prototype = cell;
        _cellClass = nil;   /* measured: prototype path leaves cellClass nil */
        [self renewRows:rows columns:cols];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithFrame:NSZeroRect]; }

/* --- cell factory --- */

- (NSCell *)makeCellAtRow:(NSInteger)row column:(NSInteger)col
{
    NSCell *cell;
    if (_prototype)
        cell = [[[_prototype class] alloc] init];  /* stage2: copy prototype's attributes */
    else
        cell = [[(_cellClass ?: [NSActionCell class]) alloc] init];
    [self putCell:cell atRow:row column:col];
    return cell;
}

- (void)renewRows:(NSInteger)newRows columns:(NSInteger)newCols
{
    if (newRows < 0) newRows = 0;
    if (newCols < 0) newCols = 0;
    NSMutableArray *grid = [NSMutableArray array];
    for (NSInteger r = 0; r < newRows; r++)
        for (NSInteger c = 0; c < newCols; c++) {
            NSCell *existing = (r < _numRows && c < _numCols) ? _cells[r * _numCols + c] : nil;
            if (existing && existing != (id)[NSNull null]) [grid addObject:existing];
            else [grid addObject:(_prototype ? [[[_prototype class] alloc] init]
                                             : [[(_cellClass ?: [NSActionCell class]) alloc] init])];
        }
    _cells = grid;
    _numRows = newRows; _numCols = newCols;
    [self _validateSelection];
}

/* --- grid access --- */

- (NSCell *)cellAtRow:(NSInteger)row column:(NSInteger)col
{
    if (row < 0 || col < 0 || row >= _numRows || col >= _numCols) return nil;
    return _cells[row * _numCols + col];
}

- (void)putCell:(NSCell *)newCell atRow:(NSInteger)row column:(NSInteger)col
{
    if (row < 0 || col < 0 || row >= _numRows || col >= _numCols || !newCell) return;
    _cells[row * _numCols + col] = newCell;
}

- (void)addRow { [self insertRow:_numRows]; }
- (void)addColumn { [self insertColumn:_numCols]; }

- (void)insertRow:(NSInteger)row
{
    if (row < 0 || row > _numRows) return;
    if (_numCols == 0) _numCols = 1;  /* first row establishes a column */
    NSInteger at = row * _numCols;
    for (NSInteger c = 0; c < _numCols; c++)
        [_cells insertObject:(_prototype ? [[[_prototype class] alloc] init]
                                         : [[(_cellClass ?: [NSActionCell class]) alloc] init])
                     atIndex:at + c];
    _numRows++;
    [self _validateSelection];
}

- (void)insertColumn:(NSInteger)col
{
    if (col < 0 || col > _numCols) return;
    NSInteger oldCols = _numCols;
    NSInteger rows = _numRows ?: (oldCols == 0 ? 1 : _numRows);
    if (_numRows == 0) _numRows = 1;
    NSInteger newCols = oldCols + 1;
    NSMutableArray *grid = [NSMutableArray array];
    for (NSInteger r = 0; r < _numRows; r++)
        for (NSInteger c = 0; c < newCols; c++) {
            if (c == col) {
                [grid addObject:(_prototype ? [[[_prototype class] alloc] init]
                                            : [[(_cellClass ?: [NSActionCell class]) alloc] init])];
            } else {
                NSInteger oc = (c < col) ? c : c - 1;
                NSCell *e = (r < rows && oc < oldCols && (r * oldCols + oc) < (NSInteger)_cells.count) ? _cells[r * oldCols + oc] : nil;
                [grid addObject:(e ?: [[(_cellClass ?: [NSActionCell class]) alloc] init])];
            }
        }
    _cells = grid; _numCols = newCols;
    [self _validateSelection];
}

- (void)removeRow:(NSInteger)row
{
    if (row < 0 || row >= _numRows) return;
    NSInteger at = row * _numCols;
    [_cells removeObjectsInRange:NSMakeRange(at, _numCols)];
    _numRows--;
    if (_numRows == 0) _numCols = 0;
    [self _validateSelection];
}

- (void)removeColumn:(NSInteger)col
{
    if (col < 0 || col >= _numCols) return;
    NSInteger oldCols = _numCols;
    NSMutableArray *grid = [NSMutableArray array];
    for (NSInteger r = 0; r < _numRows; r++)
        for (NSInteger c = 0; c < oldCols; c++)
            if (c != col) [grid addObject:_cells[r * oldCols + c]];
    _cells = grid; _numCols = oldCols - 1;
    if (_numCols == 0) _numRows = 0;
    [self _validateSelection];
}

/* --- selection --- */

- (void)_validateSelection
{
    if (_selectedRow >= _numRows || _selectedCol >= _numCols || _selectedRow < 0 || _selectedCol < 0) {
        _selectedRow = -1; _selectedCol = -1; _selectedCell = nil;
    }
}

- (void)selectCellAtRow:(NSInteger)row column:(NSInteger)col
{
    if (row == -1 && col == -1) { [self deselectAllCells]; return; }
    NSCell *cell = [self cellAtRow:row column:col];
    if (!cell) return;
    if (_mode == NSRadioModeMatrix) {
        for (NSCell *c in _cells) if (c != (id)[NSNull null]) c.state = NSControlStateValueOff;
    }
    cell.state = NSControlStateValueOn;
    _selectedCell = cell; _selectedRow = row; _selectedCol = col;
}

- (BOOL)selectCellWithTag:(NSInteger)tag
{
    for (NSInteger r = 0; r < _numRows; r++)
        for (NSInteger c = 0; c < _numCols; c++) {
            NSCell *cell = [self cellAtRow:r column:c];
            if ([self _tagOfCell:cell] == tag) { [self selectCellAtRow:r column:c]; return YES; }
        }
    return NO;
}

- (void)deselectAllCells
{
    if (!_allowsEmptySelection && _mode == NSRadioModeMatrix) return;  /* radio keeps a selection */
    for (NSCell *c in _cells) if (c != (id)[NSNull null]) c.state = NSControlStateValueOff;
    _selectedCell = nil; _selectedRow = -1; _selectedCol = -1;
}

- (void)deselectSelectedCell
{
    if (_selectedCell) _selectedCell.state = NSControlStateValueOff;
    _selectedCell = nil; _selectedRow = -1; _selectedCol = -1;
}

- (NSInteger)_tagOfCell:(NSCell *)cell
{
    if ([cell respondsToSelector:@selector(tag)]) {
        @try { return cell.tag; } @catch (__unused NSException *e) { return 0; }
    }
    return 0;
}

- (NSCell *)cellWithTag:(NSInteger)tag
{
    for (NSCell *c in _cells)
        if (c != (id)[NSNull null] && [self _tagOfCell:c] == tag) return c;
    return nil;
}

- (BOOL)getRow:(NSInteger *)row column:(NSInteger *)col ofCell:(NSCell *)cell
{
    for (NSInteger r = 0; r < _numRows; r++)
        for (NSInteger c = 0; c < _numCols; c++)
            if ([self cellAtRow:r column:c] == cell) {
                if (row) *row = r; if (col) *col = c; return YES;
            }
    return NO;
}

- (NSArray<NSCell *> *)selectedCells
{
    NSMutableArray *out = [NSMutableArray array];
    for (NSCell *c in _cells)
        if (c != (id)[NSNull null] && c.state == NSControlStateValueOn) [out addObject:c];
    return out;
}

/* --- value config --- */

- (NSArray *)cells { return [_cells copy]; }
- (NSInteger)numberOfRows { return _numRows; }
- (NSInteger)numberOfColumns { return _numCols; }
- (NSCell *)selectedCell { return _selectedCell; }
- (NSInteger)selectedRow { return _selectedRow; }
- (NSInteger)selectedColumn { return _selectedCol; }
- (Class)cellClass { return _cellClass; }
- (void)setCellClass:(Class)c { _cellClass = c; }
- (NSCell *)prototype { return _prototype; }
- (void)setPrototype:(NSCell *)p { _prototype = p; if (p) _cellClass = nil; }
- (NSMatrixMode)mode { return _mode; }
- (void)setMode:(NSMatrixMode)m { _mode = m; }
- (BOOL)allowsEmptySelection { return _allowsEmptySelection; }
- (void)setAllowsEmptySelection:(BOOL)v { _allowsEmptySelection = v; }
- (NSSize)cellSize { return _cellSize; }
- (void)setCellSize:(NSSize)s { _cellSize = s; }
- (NSSize)intercellSpacing { return _intercellSpacing; }
- (void)setIntercellSpacing:(NSSize)s { _intercellSpacing = s; }
- (NSColor *)backgroundColor { return _backgroundColor; }
- (void)setBackgroundColor:(NSColor *)c { _backgroundColor = c; }
- (NSColor *)cellBackgroundColor { return _cellBackgroundColor; }
- (void)setCellBackgroundColor:(NSColor *)c { _cellBackgroundColor = c; }
- (BOOL)drawsBackground { return _drawsBackground; }
- (void)setDrawsBackground:(BOOL)v { _drawsBackground = v; }
- (BOOL)drawsCellBackground { return _drawsCellBackground; }
- (void)setDrawsCellBackground:(BOOL)v { _drawsCellBackground = v; }
- (BOOL)autosizesCells { return _autosizesCells; }
- (void)setAutosizesCells:(BOOL)v { _autosizesCells = v; }

@end
