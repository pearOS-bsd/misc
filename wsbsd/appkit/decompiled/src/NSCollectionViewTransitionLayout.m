/*
 * NSCollectionViewTransitionLayout.m — behavioral-1:1 core.
 * See NSCollectionViewTransitionLayout.h (live per-item transition is stage2).
 */

#import "NSCollectionViewTransitionLayout.h"

@implementation NSCollectionViewTransitionLayout {
    NSCollectionViewLayout *_fromLayout;
    NSCollectionViewLayout *_toLayout;
    CGFloat _transitionProgress;
    NSMutableDictionary<NSString *, NSNumber *> *_animatedValues;
}

- (instancetype)initWithCurrentLayout:(NSCollectionViewLayout *)currentLayout
                           nextLayout:(NSCollectionViewLayout *)newLayout
{
    self = [super init];
    if (self) {
        _fromLayout = currentLayout;
        _toLayout = newLayout;
        _transitionProgress = 0.0;
        _animatedValues = [NSMutableDictionary dictionary];
    }
    return self;
}

- (instancetype)init { NSCollectionViewLayout *none = nil; return [self initWithCurrentLayout:none nextLayout:none]; }

- (NSCollectionViewLayout *)currentLayout { return _fromLayout; }
- (NSCollectionViewLayout *)nextLayout { return _toLayout; }

- (CGFloat)transitionProgress { return _transitionProgress; }
- (void)setTransitionProgress:(CGFloat)p   /* measured: not clamped */
{
    _transitionProgress = p;
    [self invalidateLayout];
}

/* --- animated key/value store (documented contract; live engine is stage2) --- */

- (void)updateValue:(CGFloat)value forAnimatedKey:(NSString *)key
{
    if (key) _animatedValues[key] = @(value);
}

- (CGFloat)valueForAnimatedKey:(NSString *)key
{
    NSNumber *v = key ? _animatedValues[key] : nil;
    return v ? v.doubleValue : 0.0;
}

/* --- attribute interpolation --- */

- (NSCollectionViewLayoutAttributes *)interpolatedLayoutAttributesFromLayoutAttributes:(NSCollectionViewLayoutAttributes *)from
                                                                     toLayoutAttributes:(NSCollectionViewLayoutAttributes *)to
                                                                               progress:(CGFloat)t
{
    NSCollectionViewLayoutAttributes *base = from ?: to;
    if (!base) return nil;
    NSCollectionViewLayoutAttributes *out =
        [NSCollectionViewLayoutAttributes layoutAttributesForItemWithIndexPath:base.indexPath];
    if (from && to) {
        NSRect f = from.frame, g = to.frame;
        out.frame = NSMakeRect(f.origin.x + (g.origin.x - f.origin.x) * t,
                               f.origin.y + (g.origin.y - f.origin.y) * t,
                               f.size.width + (g.size.width - f.size.width) * t,
                               f.size.height + (g.size.height - f.size.height) * t);
        out.alpha = from.alpha + (to.alpha - from.alpha) * t;
        out.zIndex = (t < 0.5) ? from.zIndex : to.zIndex;
    } else {
        out.frame = base.frame;
        out.alpha = base.alpha;
        out.zIndex = base.zIndex;
    }
    return out;
}

/* --- content size interpolates between the two layouts --- */

- (NSSize)collectionViewContentSize
{
    NSSize a = [_fromLayout collectionViewContentSize];
    NSSize b = [_toLayout collectionViewContentSize];
    CGFloat t = _transitionProgress;
    return NSMakeSize(a.width + (b.width - a.width) * t,
                      a.height + (b.height - a.height) * t);
}

@end
