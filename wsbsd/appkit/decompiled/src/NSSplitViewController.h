/*
 * NSSplitViewController.h — 1:1 reimplementation (core). NSViewController subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSSplitViewController : NSViewController <NSSplitViewDelegate, …> {
 *       @"NSSplitView" _splitView;  @"NSMutableArray" _splitViewItems;
 *       d _minimumThicknessForInlineSidebars;  … _flags;
 *   }
 *   -splitViewItems -setSplitViewItems: -addSplitViewItem: -insertSplitViewItem:atIndex:
 *   -removeSplitViewItem: -splitView -splitViewItemForViewController:
 *
 * Hosts a stack of NSSplitViewItems, each backed by a child view controller.
 * Adding/removing items keeps the child-view-controller list in sync. The
 * NSSplitView geometry/divider layout and sidebar collapse behaviour are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSViewController.h"

NS_ASSUME_NONNULL_BEGIN

@class NSSplitViewItem;

@interface NSSplitViewController : NSViewController

@property (copy) NSArray<NSSplitViewItem *> *splitViewItems;
@property CGFloat minimumThicknessForInlineSidebars;

- (void)addSplitViewItem:(NSSplitViewItem *)splitViewItem;
- (void)insertSplitViewItem:(NSSplitViewItem *)splitViewItem atIndex:(NSInteger)index;
- (void)removeSplitViewItem:(NSSplitViewItem *)splitViewItem;
- (nullable NSSplitViewItem *)splitViewItemForViewController:(NSViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
