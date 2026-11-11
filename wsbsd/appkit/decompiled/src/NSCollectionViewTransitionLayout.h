/*
 * NSCollectionViewTransitionLayout.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSCollectionViewTransitionLayout (: NSCollectionViewLayout), the
 * interactive layout-to-layout transition driver.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSCollectionViewTransitionLayout_interface.txt. Real ivars:
 * _fromLayout/_toLayout, _fromVisibleBounds/_toVisibleBounds, _contentSize,
 * _transitionProgress, animated-value + per-attribute transition dictionaries.
 *
 * Measured on this Mac: both layouts are stored; transitionProgress defaults to
 * 0 and is NOT clamped. This core reproduces the current/next layout identity,
 * the (unclamped) transitionProgress with invalidation, the animated-key
 * store/retrieve contract, attribute interpolation and a progress-interpolated
 * content size. Driving the real transition (per-item from/to attribute
 * resolution against the two live layouts) is TODO(stage2).
 */

#import "NSCollectionViewLayout.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionViewTransitionLayout : NSCollectionViewLayout

- (instancetype)initWithCurrentLayout:(NSCollectionViewLayout *)currentLayout
                           nextLayout:(NSCollectionViewLayout *)newLayout;

@property CGFloat transitionProgress;                      /* default 0, unclamped */
@property (readonly, strong) NSCollectionViewLayout *currentLayout;
@property (readonly, strong) NSCollectionViewLayout *nextLayout;

- (void)updateValue:(CGFloat)value forAnimatedKey:(NSString *)key;
- (CGFloat)valueForAnimatedKey:(NSString *)key;             /* default 0 */

- (NSCollectionViewLayoutAttributes *)interpolatedLayoutAttributesFromLayoutAttributes:(nullable NSCollectionViewLayoutAttributes *)fromAttributes
                                                                     toLayoutAttributes:(nullable NSCollectionViewLayoutAttributes *)toAttributes
                                                                               progress:(CGFloat)progress;

@end

NS_ASSUME_NONNULL_END
