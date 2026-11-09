/*
 * NSGridCell.m — 1:1 (core). See NSGridCell.h for the interface evidence.
 *
 * Holds the content view, the (weak) owning row/column and the placement and
 * row-alignment enums (default Inherited). The NSGridView installs the row/
 * column via the internal setters. Cell merging and the grid layout geometry
 * are stage2.
 */
#import "NSGridCell.h"

@implementation NSGridCell {
    NSView *_contentView;
    __weak id _row;
    __weak id _column;
    NSGridCellPlacement _xPlacement;
    NSGridCellPlacement _yPlacement;
    NSGridRowAlignment _rowAlignment;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _xPlacement = NSGridCellPlacementInherited;
        _yPlacement = NSGridCellPlacementInherited;
        _rowAlignment = NSGridRowAlignmentInherited;
    }
    return self;
}

- (NSView *)contentView { return _contentView; }
- (void)setContentView:(NSView *)v { _contentView = v; }
- (id)row { return _row; }
- (id)column { return _column; }
- (void)_setRow:(id)row { _row = row; }
- (void)_setColumn:(id)column { _column = column; }
- (NSGridCellPlacement)xPlacement { return _xPlacement; }
- (void)setXPlacement:(NSGridCellPlacement)v { _xPlacement = v; }
- (NSGridCellPlacement)yPlacement { return _yPlacement; }
- (void)setYPlacement:(NSGridCellPlacement)v { _yPlacement = v; }
- (NSGridRowAlignment)rowAlignment { return _rowAlignment; }
- (void)setRowAlignment:(NSGridRowAlignment)v { _rowAlignment = v; }

@end
