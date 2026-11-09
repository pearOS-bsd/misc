/*
 * NSGridColumn.m — 1:1 (core). See NSGridColumn.h for the interface evidence.
 *
 * Holds the (weak) owning grid, the column placement (default Inherited), the
 * width (default NSGridViewSizeForContent, i.e. sized to its content), the
 * leading/trailing padding and the hidden flag. The cell matrix accessors
 * (numberOfCells/cellAtIndex:) and the layout engine are stage2.
 */
#import "NSGridColumn.h"

@implementation NSGridColumn {
    __weak id _gridView;
    NSGridCellPlacement _xPlacement;
    CGFloat _width;
    CGFloat _leadingPadding;
    CGFloat _trailingPadding;
    BOOL _hidden;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _xPlacement = NSGridCellPlacementInherited;
        _width = NSGridViewSizeForContent;
    }
    return self;
}

- (id)gridView { return _gridView; }
- (void)_setGridView:(id)gridView { _gridView = gridView; }
- (NSGridCellPlacement)xPlacement { return _xPlacement; }
- (void)setXPlacement:(NSGridCellPlacement)v { _xPlacement = v; }
- (CGFloat)width { return _width; }
- (void)setWidth:(CGFloat)v { _width = v; }
- (CGFloat)leadingPadding { return _leadingPadding; }
- (void)setLeadingPadding:(CGFloat)v { _leadingPadding = v; }
- (CGFloat)trailingPadding { return _trailingPadding; }
- (void)setTrailingPadding:(CGFloat)v { _trailingPadding = v; }
- (BOOL)isHidden { return _hidden; }
- (void)setHidden:(BOOL)v { _hidden = v; }

@end
