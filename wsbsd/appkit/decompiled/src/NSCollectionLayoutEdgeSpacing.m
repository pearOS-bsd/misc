/*
 * NSCollectionLayoutEdgeSpacing.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionLayoutEdgeSpacing.h"

@implementation NSCollectionLayoutEdgeSpacing {
    NSCollectionLayoutSpacing *_leading, *_top, *_trailing, *_bottom;
}

+ (instancetype)spacingForLeading:(NSCollectionLayoutSpacing *)leading
                              top:(NSCollectionLayoutSpacing *)top
                         trailing:(NSCollectionLayoutSpacing *)trailing
                           bottom:(NSCollectionLayoutSpacing *)bottom
{
    NSCollectionLayoutEdgeSpacing *e = [[self alloc] init];
    e->_leading = leading;
    e->_top = top;
    e->_trailing = trailing;
    e->_bottom = bottom;
    return e;
}

- (NSCollectionLayoutSpacing *)leading { return _leading; }
- (NSCollectionLayoutSpacing *)top { return _top; }
- (NSCollectionLayoutSpacing *)trailing { return _trailing; }
- (NSCollectionLayoutSpacing *)bottom { return _bottom; }

- (id)copyWithZone:(NSZone *)zone
{
    return [[self class] spacingForLeading:_leading top:_top trailing:_trailing bottom:_bottom];
}

@end
