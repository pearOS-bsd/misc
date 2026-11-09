/*
 * NSSplitViewItem.h — 1:1 reimplementation (core). NSObject <NSCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSSplitViewItem : NSObject <NSAnimatablePropertyContainer, NSCoding> {
 *       @"NSViewController" _viewController;  f _holdingPriority;
 *       d _minimumThickness;  d _maximumThickness;  q _behavior;  q _collapseBehavior;
 *       {?="collapsed"b1"canCollapse"b1 …} _flags;
 *   }
 *   +splitViewItemWithViewController: -viewController -isCollapsed -setCollapsed:
 *   -holdingPriority -setHoldingPriority: -minimumThickness -maximumThickness
 *   -canCollapse -behavior
 *
 * Wraps a view controller inside an NSSplitView divider. The core tracks the
 * view controller, collapsed/canCollapse flags, holding priority, thickness
 * bounds and the behavior. The sidebar/content-list factory styling, animated
 * collapse and accessory view controllers are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class NSViewController;

typedef NS_ENUM(NSInteger, NSSplitViewItemBehavior) {
    NSSplitViewItemBehaviorDefault = 0,
    NSSplitViewItemBehaviorSidebar = 1,
    NSSplitViewItemBehaviorContentList = 2,
    NSSplitViewItemBehaviorInspector = 3,
};

static const CGFloat NSSplitViewItemUnspecifiedDimension = -1.0;

@interface NSSplitViewItem : NSObject

+ (instancetype)splitViewItemWithViewController:(NSViewController *)viewController;

@property (strong) NSViewController *viewController;
@property (getter=isCollapsed) BOOL collapsed;
@property BOOL canCollapse;
@property CGFloat holdingPriority;
@property CGFloat minimumThickness;
@property CGFloat maximumThickness;
@property (readonly) NSSplitViewItemBehavior behavior;

@end

NS_ASSUME_NONNULL_END
