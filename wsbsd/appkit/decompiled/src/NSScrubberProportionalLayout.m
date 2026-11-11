/*
 * NSScrubberProportionalLayout.m — behavioral-1:1 core. See the header.
 */

#import "NSScrubberProportionalLayout.h"
#import "NSScrubber.h"

@implementation NSScrubberProportionalLayout {
    NSInteger _numberOfVisibleItems;
}

- (instancetype)initWithNumberOfVisibleItems:(NSInteger)n
{
    self = [super init];
    if (self) _numberOfVisibleItems = (n > 0) ? n : 1;
    return self;
}

- (instancetype)init { return [self initWithNumberOfVisibleItems:5]; }  /* measured default */
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initWithNumberOfVisibleItems:5]; }

- (NSInteger)numberOfVisibleItems { return _numberOfVisibleItems; }
- (void)setNumberOfVisibleItems:(NSInteger)n { _numberOfVisibleItems = (n > 0) ? n : 1; [self invalidateLayout]; }

- (CGFloat)itemWidth
{
    NSScrubber *s = self.scrubber;
    if (!s || _numberOfVisibleItems <= 0) return 0.0;   /* stage2 without a scrubber */
    return s.bounds.size.width / (CGFloat)_numberOfVisibleItems;
}

- (CGFloat)_height { NSScrubber *s = self.scrubber; return s ? s.bounds.size.height : 0.0; }

- (NSScrubberLayoutAttributes *)layoutAttributesForItemAtIndex:(NSInteger)index
{
    if (index < 0) return nil;
    NSScrubberLayoutAttributes *a = [NSScrubberLayoutAttributes layoutAttributesForItemAtIndex:index];
    CGFloat w = [self itemWidth];
    a.frame = NSMakeRect(index * w, 0, w, [self _height]);
    return a;
}

- (NSSize)scrubberContentSize
{
    NSScrubber *s = self.scrubber;
    NSInteger n = s ? s.numberOfItems : 0;
    if (n <= 0) return NSZeroSize;
    return NSMakeSize(n * [self itemWidth], [self _height]);
}

- (NSSet<NSScrubberLayoutAttributes *> *)layoutAttributesForItemsInRect:(NSRect)rect
{
    NSMutableSet *out = [NSMutableSet set];
    NSScrubber *s = self.scrubber;
    NSInteger n = s ? s.numberOfItems : 0;
    for (NSInteger i = 0; i < n; i++) {
        NSScrubberLayoutAttributes *a = [self layoutAttributesForItemAtIndex:i];
        if (NSIntersectsRect(a.frame, rect)) [out addObject:a];
    }
    return out;
}

- (BOOL)shouldInvalidateLayoutForChangeFromVisibleRect:(NSRect)from toVisibleRect:(NSRect)to { return YES; }

@end
