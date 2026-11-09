/*
 * NSTabViewController.h — 1:1 reimplementation (core). NSViewController subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSTabViewController : NSViewController <NSTabViewDelegate, …> {
 *       @"NSTabView" _tabView;  … _tabViewControllerFlags;
 *   }
 *   @property (Tq) tabStyle;  (T@"NSArray",C) tabViewItems;
 *   @property (Tq) selectedTabViewItemIndex;  (TQ) transitionOptions;
 *   -addTabViewItem: -insertTabViewItem:atIndex: -removeTabViewItem:
 *   -tabViewItemForViewController:
 *
 * Presents a set of tab view items (each backed by a child view controller) and
 * tracks the selected index and tab style. Adding/removing items keeps the
 * child-view-controller list in sync. The tab bar / segmented control UI and
 * the transition animations are stage2.
 */
#import <Foundation/Foundation.h>
#import "NSViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTabViewItem;

typedef NS_ENUM(NSInteger, NSTabViewControllerTabStyle) {
    NSTabViewControllerTabStyleSegmentedControlOnTop = 0,
    NSTabViewControllerTabStyleSegmentedControlOnBottom = 1,
    NSTabViewControllerTabStyleToolbar = 2,
    NSTabViewControllerTabStyleUnspecified = -1,
};

@interface NSTabViewController : NSViewController

@property NSTabViewControllerTabStyle tabStyle;
@property (copy) NSArray<NSTabViewItem *> *tabViewItems;
@property NSInteger selectedTabViewItemIndex;

- (void)addTabViewItem:(NSTabViewItem *)tabViewItem;
- (void)insertTabViewItem:(NSTabViewItem *)tabViewItem atIndex:(NSInteger)index;
- (void)removeTabViewItem:(NSTabViewItem *)tabViewItem;
- (nullable NSTabViewItem *)tabViewItemForViewController:(NSViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
