/*
 * NSGridRow.m — 1:1 (core). See NSGridRow.h for the interface evidence.
 *
 * The row owns its cell array (_cells); numberOfCells and cellAtIndex: read it
 * directly, raising on an out-of-range index like AppKit. yPlacement defaults
 * to Inherited, rowAlignment to Inherited, height to NSGridViewSizeForContent.
 * The grid installs the cells and the owning grid through the internal glue.
 * Layout geometry is stage2.
 */
#import "NSGridRow.h"

@implementation NSGridRow {
    __weak id _gridView;
    NSMutableArray<NSGridCell *> *_cells;
    NSGridCellPlacement _yPlacement;
    NSGridRowAlignment _rowAlignment;
    CGFloat _height;
    CGFloat _topPadding;
    CGFloat _bottomPadding;
    BOOL _hidden;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cells = [NSMutableArray array];
        _yPlacement = NSGridCellPlacementInherited;
        _rowAlignment = NSGridRowAlignmentInherited;
        _height = NSGridViewSizeForContent;
    }
    return self;
}

- (id)gridView { return _gridView; }
- (void)_setGridView:(id)gridView { _gridView = gridView; }
- (void)_addCell:(NSGridCell *)cell { if (cell) [_cells addObject:cell]; }

- (NSInteger)numberOfCells { return (NSInteger)_cells.count; }
- (NSGridCell *)cellAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_cells.count)
        [NSException raise:NSRangeException format:@"NSGridRow cell index %ld out of range", (long)index];
    return _cells[index];
}

- (NSGridCellPlacement)yPlacement { return _yPlacement; }
- (void)setYPlacement:(NSGridCellPlacement)v { _yPlacement = v; }
- (NSGridRowAlignment)rowAlignment { return _rowAlignment; }
- (void)setRowAlignment:(NSGridRowAlignment)v { _rowAlignment = v; }
- (CGFloat)height { return _height; }
- (void)setHeight:(CGFloat)v { _height = v; }
- (CGFloat)topPadding { return _topPadding; }
- (void)setTopPadding:(CGFloat)v { _topPadding = v; }
- (CGFloat)bottomPadding { return _bottomPadding; }
- (void)setBottomPadding:(CGFloat)v { _bottomPadding = v; }
- (BOOL)isHidden { return _hidden; }
- (void)setHidden:(BOOL)v { _hidden = v; }

@end
