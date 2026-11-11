/*
 * NSScrubberFlowLayout.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSScrubberFlowLayout (: NSScrubberLayout), the fixed-item-size horizontal flow
 * layout for NSScrubber.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSScrubberFlowLayout_interface.txt. Real ivars: _itemSpacing,
 * _itemSize, _support.
 *
 * Measured on this Mac: itemSpacing default 0, itemSize default {50,30}.
 *
 * This core reproduces the horizontal-flow geometry (each item at
 * x = index*(itemWidth + itemSpacing), size = itemSize) and the layout
 * attributes/content-size derivation. The on-Mac getter returns nil without an
 * installed scrubber; this core computes the attributes directly so they are
 * testable. Live invalidation gating is TODO(stage2).
 */

#import "NSScrubberLayout.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSScrubberFlowLayout : NSScrubberLayout

@property CGFloat itemSpacing;          /* default 0 */
@property NSSize itemSize;              /* default {50,30} */

- (void)invalidateLayoutForItemsAtIndexes:(NSIndexSet *)indexes;

@end

NS_ASSUME_NONNULL_END
