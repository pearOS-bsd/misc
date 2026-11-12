/*
 * NSTrackingSeparatorToolbarItem.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSTrackingSeparatorToolbarItem, the toolbar divider that aligns with
 * a split-view divider.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSTrackingSeparatorToolbarItem_interface.txt. Superclass is
 * NSToolbarItem. Real ivars: _view (NSSeparatorToolbarItemView), a _flags
 * bitfield (alignment bookkeeping), representsSidebar, representsTrailingSidebar.
 *
 * Public surface: the +trackingSeparatorToolbarItemWithIdentifier:splitView:
 * dividerIndex: factory and the splitView / dividerIndex properties. This core
 * reproduces that configuration (factory stores both; plain init leaves
 * splitView=nil, dividerIndex=0 — measured). The alignment tracking, the
 * separator view and the KVO on the split view's divider position are
 * TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSToolbarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSSplitView;

@interface NSTrackingSeparatorToolbarItem : NSToolbarItem

+ (instancetype)trackingSeparatorToolbarItemWithIdentifier:(NSString *)identifier
                                                 splitView:(NSSplitView *)splitView
                                              dividerIndex:(NSInteger)dividerIndex;

@property (strong) NSSplitView *splitView;
@property NSInteger dividerIndex;

@end

NS_ASSUME_NONNULL_END
