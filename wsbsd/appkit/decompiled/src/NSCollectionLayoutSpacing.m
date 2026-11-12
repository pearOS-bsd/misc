/*
 * NSCollectionLayoutSpacing.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionLayoutSpacing.h"

@implementation NSCollectionLayoutSpacing {
    CGFloat _spacing;
    BOOL _flexible;
}

+ (instancetype)flexibleSpacing:(CGFloat)flexibleSpacing
{
    NSCollectionLayoutSpacing *s = [[self alloc] init];
    s->_spacing = flexibleSpacing;
    s->_flexible = YES;
    return s;
}

+ (instancetype)fixedSpacing:(CGFloat)fixedSpacing
{
    NSCollectionLayoutSpacing *s = [[self alloc] init];
    s->_spacing = fixedSpacing;
    s->_flexible = NO;
    return s;
}

- (CGFloat)spacing { return _spacing; }
- (BOOL)isFlexibleSpacing { return _flexible; }
- (BOOL)isFixedSpacing { return !_flexible; }

- (id)copyWithZone:(NSZone *)zone
{
    return _flexible ? [[self class] flexibleSpacing:_spacing] : [[self class] fixedSpacing:_spacing];
}

@end
