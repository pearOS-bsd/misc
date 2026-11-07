/*
 * NSTabView.h — 1:1 reimplementation (core). NSView subclass.
 * Evidence ../evidence/tab: the tab-view items live in an internal array;
 * numberOfTabViewItems/tabViewItems read it. Tab drawing/selection UI is stage2.
 */
#import "NSView.h"
#import "NSTabViewItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSTabView : NSView
- (void)addTabViewItem:(NSTabViewItem *)item;
- (void)insertTabViewItem:(NSTabViewItem *)item atIndex:(NSInteger)index;
- (void)removeTabViewItem:(NSTabViewItem *)item;
@property (readonly) NSInteger numberOfTabViewItems;
@property (readonly, copy) NSArray<NSTabViewItem *> *tabViewItems;
- (NSInteger)indexOfTabViewItem:(NSTabViewItem *)item;
- (NSTabViewItem *)tabViewItemAtIndex:(NSInteger)index;
- (void)selectTabViewItemAtIndex:(NSInteger)index;
@property (nullable, readonly) NSTabViewItem *selectedTabViewItem;
@end

NS_ASSUME_NONNULL_END
