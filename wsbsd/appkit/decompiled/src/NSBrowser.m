/*
 * NSBrowser.m — behavioral-1:1 core. See the header.
 */

#import "NSBrowser.h"

@implementation NSBrowser {
    __weak id _delegate;
    NSInteger _maxVisibleColumns;
    CGFloat _minColumnWidth;
    BOOL _hasHorizontalScroller;
    BOOL _allowsMultipleSelection;
    BOOL _allowsEmptySelection;
    BOOL _allowsBranchSelection;
    BOOL _separatesColumns;
    BOOL _titled;
    BOOL _reusesColumns;
    NSString *_pathSeparator;
    BOOL _takesTitleFromPreviousColumn;
    NSInteger _lastColumn;        /* -1 when no column is loaded */
    NSInteger _selectedColumn;    /* -1 when nothing is selected */
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _minColumnWidth = 100.0;            /* measured */
        _allowsEmptySelection = YES;        /* measured */
        _separatesColumns = YES;            /* measured */
        _titled = YES;                      /* measured */
        _takesTitleFromPreviousColumn = YES;/* measured */
        _pathSeparator = @"/";              /* measured */
        _lastColumn = -1;                   /* measured */
        _selectedColumn = -1;               /* measured */
        /* maxVisibleColumns=0, hasHorizontalScroller=NO, allowsMultipleSelection=NO,
           allowsBranchSelection=NO, reusesColumns=NO (measured). */
    }
    return self;
}

- (id)delegate { return _delegate; }
- (void)setDelegate:(id)d { _delegate = d; }
- (NSInteger)maxVisibleColumns { return _maxVisibleColumns; }
- (void)setMaxVisibleColumns:(NSInteger)v { _maxVisibleColumns = v; }
- (CGFloat)minColumnWidth { return _minColumnWidth; }
- (void)setMinColumnWidth:(CGFloat)v { _minColumnWidth = v; }
- (BOOL)hasHorizontalScroller { return _hasHorizontalScroller; }
- (void)setHasHorizontalScroller:(BOOL)v { _hasHorizontalScroller = v; }
- (BOOL)allowsMultipleSelection { return _allowsMultipleSelection; }
- (void)setAllowsMultipleSelection:(BOOL)v { _allowsMultipleSelection = v; }
- (BOOL)allowsEmptySelection { return _allowsEmptySelection; }
- (void)setAllowsEmptySelection:(BOOL)v { _allowsEmptySelection = v; }
- (BOOL)allowsBranchSelection { return _allowsBranchSelection; }
- (void)setAllowsBranchSelection:(BOOL)v { _allowsBranchSelection = v; }
- (BOOL)separatesColumns { return _separatesColumns; }
- (void)setSeparatesColumns:(BOOL)v { _separatesColumns = v; }
- (BOOL)isTitled { return _titled; }
- (void)setTitled:(BOOL)v { _titled = v; }
- (BOOL)reusesColumns { return _reusesColumns; }
- (void)setReusesColumns:(BOOL)v { _reusesColumns = v; }
- (NSString *)pathSeparator { return _pathSeparator; }
- (void)setPathSeparator:(NSString *)s { _pathSeparator = [s copy] ?: @"/"; }
- (BOOL)takesTitleFromPreviousColumn { return _takesTitleFromPreviousColumn; }
- (void)setTakesTitleFromPreviousColumn:(BOOL)v { _takesTitleFromPreviousColumn = v; }

- (NSInteger)lastColumn { return _lastColumn; }
- (NSInteger)selectedColumn { return _selectedColumn; }
- (NSInteger)numberOfVisibleColumns { return _lastColumn < 0 ? 0 : _lastColumn + 1; }

- (void)loadColumnZero
{
    _lastColumn = 0;        /* column 0 becomes the only loaded column */
    _selectedColumn = -1;
}

- (void)addColumn { _lastColumn += 1; }

- (void)setLastColumn:(NSInteger)column
{
    if (column < -1) column = -1;
    _lastColumn = column;
    if (_selectedColumn > column) _selectedColumn = column;
}

- (void)selectRow:(NSInteger)row inColumn:(NSInteger)column
{
    if (column < 0 || column > _lastColumn) return;
    _selectedColumn = column;   /* the cell/row selection within it is stage2 */
}

- (void)reloadColumn:(NSInteger)column { /* TODO(stage2): re-query the delegate for the column's rows. */ }

@end
