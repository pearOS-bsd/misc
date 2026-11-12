/*
 * NSCollectionLayoutDecorationItem.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionLayoutDecorationItem.h"

@implementation NSCollectionLayoutDecorationItem {
    NSString *_elementKind;
    NSInteger _zIndex;
}
@synthesize zIndex = _zIndex;

+ (instancetype)backgroundDecorationItemWithElementKind:(NSString *)elementKind
{
    NSCollectionLayoutDecorationItem *d = [[self alloc] init];
    d->_elementKind = [elementKind copy];
    d->_zIndex = 0;   /* measured default (behind content) */
    return d;
}

- (NSString *)elementKind { return _elementKind; }

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutDecorationItem *c = [[self class] backgroundDecorationItemWithElementKind:_elementKind];
    c->_zIndex = _zIndex;
    c.contentInsets = self.contentInsets;
    return c;
}

@end
