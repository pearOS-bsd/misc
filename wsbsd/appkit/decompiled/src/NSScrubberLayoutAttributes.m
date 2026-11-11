/*
 * NSScrubberLayoutAttributes.m — 1:1 value object. See the header.
 */

#import "NSScrubberLayoutAttributes.h"

@implementation NSScrubberLayoutAttributes

+ (instancetype)layoutAttributesForItemAtIndex:(NSInteger)index
{
    NSScrubberLayoutAttributes *a = [[self alloc] init];
    a.itemIndex = index;
    return a;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _itemIndex = -1;    /* measured */
        _alpha = 1.0;       /* measured */
        _frame = NSZeroRect;
        _escapesFromScrollView = NO;
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSScrubberLayoutAttributes *c = [[[self class] alloc] init];
    c->_itemIndex = _itemIndex;
    c->_frame = _frame;
    c->_alpha = _alpha;
    c->_escapesFromScrollView = _escapesFromScrollView;
    return c;
}

- (BOOL)isEqual:(id)other
{
    if (self == other) return YES;
    if (![other isKindOfClass:[NSScrubberLayoutAttributes class]]) return NO;
    NSScrubberLayoutAttributes *o = other;
    return _itemIndex == o->_itemIndex
        && _alpha == o->_alpha
        && NSEqualRects(_frame, o->_frame);
}

- (NSUInteger)hash { return (NSUInteger)_itemIndex ^ (NSUInteger)_frame.size.width; }

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: idx=%ld frame=%@ alpha=%g>",
            [self class], (long)_itemIndex, NSStringFromRect(_frame), _alpha];
}

@end
