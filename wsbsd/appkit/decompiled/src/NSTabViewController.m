/*
 * NSTabViewController.m — 1:1 (core). See NSTabViewController.h for evidence.
 *
 * Keeps an ordered list of tab view items; each item's view controller is added
 * as a child view controller (and removed when its item is removed), mirroring
 * AppKit. selectedTabViewItemIndex defaults to 0 once there is at least one
 * item and is clamped to the valid range. tabStyle defaults to
 * SegmentedControlOnTop. The tab bar UI and transition animations are stage2.
 */
#import "NSTabViewController.h"
#import "NSTabViewItem.h"

@implementation NSTabViewController {
    NSMutableArray<NSTabViewItem *> *_items;
    NSInteger _selectedIndex;
    NSTabViewControllerTabStyle _tabStyle;
}

- (instancetype)initWithNibName:(NSString *)nib bundle:(NSBundle *)bundle
{
    self = [super initWithNibName:nib bundle:bundle];
    if (self) {
        _items = [NSMutableArray array];
        _selectedIndex = -1;    /* no selection until an item exists */
        _tabStyle = NSTabViewControllerTabStyleSegmentedControlOnTop;
    }
    return self;
}

- (NSTabViewControllerTabStyle)tabStyle { return _tabStyle; }
- (void)setTabStyle:(NSTabViewControllerTabStyle)v { _tabStyle = v; }

- (NSArray<NSTabViewItem *> *)tabViewItems { return [_items copy]; }
- (void)setTabViewItems:(NSArray<NSTabViewItem *> *)items
{
    while (_items.count) [self removeTabViewItem:_items.lastObject];
    for (NSTabViewItem *i in items) [self addTabViewItem:i];
}

- (NSInteger)selectedTabViewItemIndex { return _selectedIndex; }
- (void)setSelectedTabViewItemIndex:(NSInteger)index
{
    if (_items.count == 0) { _selectedIndex = -1; return; }
    if (index < 0) index = 0;
    if (index >= (NSInteger)_items.count) index = _items.count - 1;
    _selectedIndex = index;
}

- (void)addTabViewItem:(NSTabViewItem *)item
{
    [self insertTabViewItem:item atIndex:_items.count];
}

- (void)insertTabViewItem:(NSTabViewItem *)item atIndex:(NSInteger)index
{
    if (!item) return;
    if (index < 0 || index > (NSInteger)_items.count) index = _items.count;
    [_items insertObject:item atIndex:index];
    if (item.viewController) [self addChildViewController:item.viewController];
    if (_selectedIndex < 0) _selectedIndex = 0;   /* first item becomes selected */
}

- (void)removeTabViewItem:(NSTabViewItem *)item
{
    NSUInteger idx = [_items indexOfObjectIdenticalTo:item];
    if (idx == NSNotFound) return;
    if (item.viewController) [item.viewController removeFromParentViewController];
    [_items removeObjectAtIndex:idx];
    /* keep the selection valid */
    if (_items.count == 0) _selectedIndex = -1;
    else if (_selectedIndex >= (NSInteger)_items.count) _selectedIndex = _items.count - 1;
}

- (NSTabViewItem *)tabViewItemForViewController:(NSViewController *)viewController
{
    for (NSTabViewItem *i in _items)
        if (i.viewController == viewController) return i;
    return nil;
}

@end
