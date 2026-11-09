/*
 * NSTextTable.m — 1:1 (core). See NSTextTable.h for the interface evidence.
 *
 * Inherits NSTextBlock. Stores the column count, the layout algorithm (default
 * Automatic) and the collapsesBorders / hidesEmptyCells flags (the _tableFlags
 * bits). The table geometry (rectForBlock:… / column widths) is stage2.
 */
#import "NSTextTable.h"

@implementation NSTextTable {
    NSUInteger _numCols;
    NSTextTableLayoutAlgorithm _layoutAlgorithm;
    BOOL _collapsesBorders;
    BOOL _hidesEmptyCells;
}

- (NSUInteger)numberOfColumns { return _numCols; }
- (void)setNumberOfColumns:(NSUInteger)v { _numCols = v; }
- (NSTextTableLayoutAlgorithm)layoutAlgorithm { return _layoutAlgorithm; }
- (void)setLayoutAlgorithm:(NSTextTableLayoutAlgorithm)v { _layoutAlgorithm = v; }
- (BOOL)collapsesBorders { return _collapsesBorders; }
- (void)setCollapsesBorders:(BOOL)v { _collapsesBorders = v; }
- (BOOL)hidesEmptyCells { return _hidesEmptyCells; }
- (void)setHidesEmptyCells:(BOOL)v { _hidesEmptyCells = v; }

- (id)copyWithZone:(NSZone *)zone
{
    NSTextTable *c = [super copyWithZone:zone];
    c->_numCols = _numCols;
    c->_layoutAlgorithm = _layoutAlgorithm;
    c->_collapsesBorders = _collapsesBorders;
    c->_hidesEmptyCells = _hidesEmptyCells;
    return c;
}

@end
