/*
 * NSSplitViewController.m — 1:1 (core). See NSSplitViewController.h for evidence.
 *
 * Keeps an ordered list of split view items; each item's view controller is
 * added as a child view controller on insert and detached on remove, mirroring
 * AppKit. splitViewItemForViewController: matches by the item's viewController.
 * The NSSplitView divider layout, inline-sidebar thickness and collapse
 * animations are stage2.
 */
#import "NSSplitViewController.h"
#import "NSSplitViewItem.h"

@implementation NSSplitViewController {
    NSMutableArray<NSSplitViewItem *> *_items;
    CGFloat _minimumThicknessForInlineSidebars;
}

- (instancetype)initWithNibName:(NSString *)nib bundle:(NSBundle *)bundle
{
    self = [super initWithNibName:nib bundle:bundle];
    if (self) {
        _items = [NSMutableArray array];
        _minimumThicknessForInlineSidebars = -1.0; /* NSSplitViewItemUnspecifiedDimension */
    }
    return self;
}

- (CGFloat)minimumThicknessForInlineSidebars { return _minimumThicknessForInlineSidebars; }
- (void)setMinimumThicknessForInlineSidebars:(CGFloat)v { _minimumThicknessForInlineSidebars = v; }

- (NSArray<NSSplitViewItem *> *)splitViewItems { return [_items copy]; }
- (void)setSplitViewItems:(NSArray<NSSplitViewItem *> *)items
{
    while (_items.count) [self removeSplitViewItem:_items.lastObject];
    for (NSSplitViewItem *i in items) [self addSplitViewItem:i];
}

- (void)addSplitViewItem:(NSSplitViewItem *)item
{
    [self insertSplitViewItem:item atIndex:_items.count];
}

- (void)insertSplitViewItem:(NSSplitViewItem *)item atIndex:(NSInteger)index
{
    if (!item) return;
    if (index < 0 || index > (NSInteger)_items.count) index = _items.count;
    [_items insertObject:item atIndex:index];
    if (item.viewController) [self addChildViewController:item.viewController];
}

- (void)removeSplitViewItem:(NSSplitViewItem *)item
{
    NSUInteger idx = [_items indexOfObjectIdenticalTo:item];
    if (idx == NSNotFound) return;
    if (item.viewController) [item.viewController removeFromParentViewController];
    [_items removeObjectAtIndex:idx];
}

- (NSSplitViewItem *)splitViewItemForViewController:(NSViewController *)viewController
{
    for (NSSplitViewItem *i in _items)
        if (i.viewController == viewController) return i;
    return nil;
}

@end
