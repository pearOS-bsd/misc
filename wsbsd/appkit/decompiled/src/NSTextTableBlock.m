/*
 * NSTextTableBlock.m — 1:1 (core). See NSTextTableBlock.h for interface evidence.
 *
 * Inherits NSTextBlock; adds the owning table and the (row, rowSpan, column,
 * columnSpan) placement set at init. copy carries both the inherited block state
 * (via super, which is polymorphic) and the table coordinates. The block layout
 * inside the table is stage2.
 */
#import "NSTextTableBlock.h"

@implementation NSTextTableBlock {
    NSTextTable *_table;
    NSInteger _rowNum, _colNum, _rowSpan, _colSpan;
}

- (instancetype)initWithTable:(NSTextTable *)table
                  startingRow:(NSInteger)row rowSpan:(NSInteger)rowSpan
               startingColumn:(NSInteger)col columnSpan:(NSInteger)colSpan
{
    self = [super init];
    if (self) {
        _table = table;
        _rowNum = row; _rowSpan = rowSpan;
        _colNum = col; _colSpan = colSpan;
    }
    return self;
}

- (NSTextTable *)table { return _table; }
- (NSInteger)startingRow { return _rowNum; }
- (NSInteger)rowSpan { return _rowSpan; }
- (NSInteger)startingColumn { return _colNum; }
- (NSInteger)columnSpan { return _colSpan; }

- (id)copyWithZone:(NSZone *)zone
{
    NSTextTableBlock *c = [super copyWithZone:zone];   /* polymorphic: an NSTextTableBlock */
    c->_table = _table;
    c->_rowNum = _rowNum; c->_rowSpan = _rowSpan;
    c->_colNum = _colNum; c->_colSpan = _colSpan;
    return c;
}

@end
