/*
 * NSScrubberFlowLayout.m — behavioral-1:1 horizontal-flow geometry. See the header.
 */

#import "NSScrubberFlowLayout.h"
#import "NSScrubber.h"

@implementation NSScrubberFlowLayout {
    CGFloat _itemSpacing;
    NSSize _itemSize;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _itemSpacing = 0.0;               /* measured */
        _itemSize = NSMakeSize(50, 30);   /* measured */
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }

- (CGFloat)itemSpacing { return _itemSpacing; }
- (void)setItemSpacing:(CGFloat)s { _itemSpacing = s; [self invalidateLayout]; }
- (NSSize)itemSize { return _itemSize; }
- (void)setItemSize:(NSSize)s { _itemSize = s; [self invalidateLayout]; }

- (void)invalidateLayoutForItemsAtIndexes:(NSIndexSet *)indexes { [self invalidateLayout]; }

- (NSScrubberLayoutAttributes *)layoutAttributesForItemAtIndex:(NSInteger)index
{
    if (index < 0) return nil;
    NSScrubberLayoutAttributes *a = [NSScrubberLayoutAttributes layoutAttributesForItemAtIndex:index];
    CGFloat x = index * (_itemSize.width + _itemSpacing);
    a.frame = NSMakeRect(x, 0, _itemSize.width, _itemSize.height);
    return a;
}

- (NSInteger)_itemCount
{
    NSScrubber *s = self.scrubber;
    return s ? s.numberOfItems : 0;   /* stage2 without a scrubber */
}

- (NSSize)scrubberContentSize
{
    NSInteger n = [self _itemCount];
    if (n <= 0) return NSZeroSize;
    CGFloat w = n * _itemSize.width + (n - 1) * _itemSpacing;
    return NSMakeSize(w, _itemSize.height);
}

- (NSSet<NSScrubberLayoutAttributes *> *)layoutAttributesForItemsInRect:(NSRect)rect
{
    NSMutableSet *out = [NSMutableSet set];
    NSInteger n = [self _itemCount];
    for (NSInteger i = 0; i < n; i++) {
        NSScrubberLayoutAttributes *a = [self layoutAttributesForItemAtIndex:i];
        if (NSIntersectsRect(a.frame, rect)) [out addObject:a];
    }
    return out;
}

@end
