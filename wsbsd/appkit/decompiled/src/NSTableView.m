/*
 * NSTableView.m — 1:1 (core). Evidence ../evidence/table:
 * tableColumns 0x184f70c0c ([self+0xefc]), numberOfColumns 0x184f70998
 * ([columns count]), addTableColumn: 0x1850b6b7c (append), setRowHeight:
 * 0x1850d2400 (reject <= 0), allowsColumnReordering 0x1857fa6bc (_tvFlags bit 31).
 */
#import "NSTableView.h"

@implementation NSTableView {
    NSMutableArray<NSTableColumn *> *_tableColumns;   /* 0xefc */
    CGFloat _rowHeight;
    uint32_t _tvFlags;                                /* 0xf08 */
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _tableColumns = [NSMutableArray array];
        _rowHeight = 17.0;              /* conventional default */
        _tvFlags |= 0x80000000u;        /* allowsColumnReordering defaults YES */
    }
    return self;
}

- (void)addTableColumn:(NSTableColumn *)column
{
    if (!column) return;
    [_tableColumns addObject:column];
    /* TODO(stage2): set column.tableView back-link, retile, header. */
}

- (void)removeTableColumn:(NSTableColumn *)column
{
    NSUInteger idx = [_tableColumns indexOfObjectIdenticalTo:column];
    if (idx != NSNotFound) [_tableColumns removeObjectAtIndex:idx];
}

- (NSArray<NSTableColumn *> *)tableColumns { return [_tableColumns copy]; }
- (NSInteger)numberOfColumns { return (NSInteger)_tableColumns.count; }

- (NSTableColumn *)columnWithIdentifier:(NSString *)identifier
{
    for (NSTableColumn *c in _tableColumns)
        if ([c.identifier isEqual:identifier]) return c;
    return nil;
}
- (NSInteger)columnIndexWithIdentifier:(NSString *)identifier
{
    for (NSUInteger i = 0; i < _tableColumns.count; i++)
        if ([_tableColumns[i].identifier isEqual:identifier]) return (NSInteger)i;
    return -1;
}

- (CGFloat)rowHeight { return _rowHeight; }
- (void)setRowHeight:(CGFloat)rowHeight { if (rowHeight > 0.0) _rowHeight = rowHeight; }  /* reject <= 0 */

- (BOOL)allowsColumnReordering { return (_tvFlags >> 31) & 1u; }
- (void)setAllowsColumnReordering:(BOOL)v
{
    if (v) _tvFlags |= 0x80000000u;
    else   _tvFlags &= ~0x80000000u;
}

@end
