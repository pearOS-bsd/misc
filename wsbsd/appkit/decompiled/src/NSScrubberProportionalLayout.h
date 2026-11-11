/*
 * NSScrubberProportionalLayout.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSScrubberProportionalLayout (: NSScrubberLayout), which sizes each
 * item to a fixed fraction of the scrubber's width.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSScrubberProportionalLayout_interface.txt. Real ivar:
 * _numberOfVisibleItems.
 *
 * Measured on this Mac: numberOfVisibleItems default 5;
 * shouldInvalidateLayoutForChangeFromVisibleRect:toVisibleRect: = YES (the item
 * width is proportional to the scrubber width, so it re-lays on size change).
 *
 * This core reproduces the item-width formula (scrubberWidth / visibleItems) and
 * the per-item frames. The scrubber bounds and item count come from the installed
 * scrubber (itemWidth is 0 without one) = stage2.
 */

#import "NSScrubberLayout.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSScrubberProportionalLayout : NSScrubberLayout

- (instancetype)initWithNumberOfVisibleItems:(NSInteger)numberOfVisibleItems;
@property NSInteger numberOfVisibleItems;     /* default 5 */
- (CGFloat)itemWidth;

@end

NS_ASSUME_NONNULL_END
