/*
 * NSComboBoxCell.m — 1:1 (core). Evidence ../evidence/combo:
 * numberOfVisibleItems 0x1851b32fc (_cbcFlags halfword @+2), setNumberOfVisibleItems:
 * 0x1851b21e8 (cap 0xffff), usesDataSource 0x1851b2f84 (_cbcFlags bit 0).
 */
#import "NSComboBoxCell.h"

@implementation NSComboBoxCell {
    uint32_t _cbcFlags;              /* 0xe40: bit0 usesDataSource, high16 numberOfVisibleItems */
    BOOL _hasVerticalScroller;       /* shipping: pop-up scroll view @0xe34 (stage2) */
    NSMutableArray *_items;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _items = [NSMutableArray array]; _hasVerticalScroller = YES; }
    return self;
}

- (NSInteger)numberOfVisibleItems { return (_cbcFlags >> 16) & 0xffff; }
- (void)setNumberOfVisibleItems:(NSInteger)n
{
    uint32_t v = (n < 0) ? 0 : (n > 0xffff ? 0xffff : (uint32_t)n);   /* binary caps at 0xffff */
    _cbcFlags = (_cbcFlags & 0x0000ffffu) | (v << 16);
}

- (BOOL)usesDataSource { return (_cbcFlags & 0x1u) != 0; }
- (void)setUsesDataSource:(BOOL)v { if (v) _cbcFlags |= 0x1u; else _cbcFlags &= ~0x1u; }

- (BOOL)hasVerticalScroller { return _hasVerticalScroller; }
- (void)setHasVerticalScroller:(BOOL)v { _hasVerticalScroller = v; }

- (NSInteger)numberOfItems { return (NSInteger)_items.count; }
- (void)addItemWithObjectValue:(id)object { if (object) [_items addObject:object]; }
- (id)itemObjectValueAtIndex:(NSInteger)index { return _items[(NSUInteger)index]; }

@end
