/*
 * NSTabView.m — 1:1 (core). Evidence ../evidence/tab:
 * numberOfTabViewItems 0x185072a78 ([items count]), tabViewItems 0x185071974
 * (copy), addTabViewItem: 0x185107c34 (append). Selection + tab drawing stage2.
 */
#import "NSTabView.h"

@implementation NSTabView {
    NSMutableArray<NSTabViewItem *> *_items;
    NSInteger _selectedIndex;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) { _items = [NSMutableArray array]; _selectedIndex = -1; }
    return self;
}

- (void)addTabViewItem:(NSTabViewItem *)item { [self insertTabViewItem:item atIndex:(NSInteger)_items.count]; }

- (void)insertTabViewItem:(NSTabViewItem *)item atIndex:(NSInteger)index
{
    if (!item || index < 0 || (NSUInteger)index > _items.count) return;
    [_items insertObject:item atIndex:(NSUInteger)index];
    if (_selectedIndex < 0) _selectedIndex = 0;   /* first item selected */
}

- (void)removeTabViewItem:(NSTabViewItem *)item
{
    NSUInteger idx = [_items indexOfObjectIdenticalTo:item];
    if (idx == NSNotFound) return;
    [_items removeObjectAtIndex:idx];
    if (_selectedIndex >= (NSInteger)_items.count) _selectedIndex = (NSInteger)_items.count - 1;
}

- (NSInteger)numberOfTabViewItems { return (NSInteger)_items.count; }
- (NSArray<NSTabViewItem *> *)tabViewItems { return [_items copy]; }

- (NSInteger)indexOfTabViewItem:(NSTabViewItem *)item
{
    NSUInteger idx = [_items indexOfObjectIdenticalTo:item];
    return (idx == NSNotFound) ? NSNotFound : (NSInteger)idx;
}

- (NSTabViewItem *)tabViewItemAtIndex:(NSInteger)index { return _items[(NSUInteger)index]; }

- (void)selectTabViewItemAtIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_items.count) return;
    _selectedIndex = index;
}

- (NSTabViewItem *)selectedTabViewItem
{
    if (_selectedIndex < 0 || _selectedIndex >= (NSInteger)_items.count) return nil;
    return _items[(NSUInteger)_selectedIndex];
}

@end
