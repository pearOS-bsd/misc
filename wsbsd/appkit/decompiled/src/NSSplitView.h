/*
 * NSSplitView.h — 1:1 reimplementation (core). NSView subclass.
 * Evidence ../evidence/split: isVertical = a flags bit (0x40000), dividerStyle a
 * separate ivar (0x9e0). dividerThickness is derived from the style (exact pt
 * values + divider dragging/layout are stage2).
 */
#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSSplitViewDividerStyle) {
    NSSplitViewDividerStyleThick = 1,
    NSSplitViewDividerStyleThin = 2,
    NSSplitViewDividerStylePaneSplitter = 3,
};

@interface NSSplitView : NSView
@property (getter=isVertical) BOOL vertical;
@property NSSplitViewDividerStyle dividerStyle;
@property (readonly) CGFloat dividerThickness;
@end

NS_ASSUME_NONNULL_END
