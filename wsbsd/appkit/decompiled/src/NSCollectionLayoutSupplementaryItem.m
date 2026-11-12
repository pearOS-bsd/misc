/*
 * NSCollectionLayoutSupplementaryItem.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionLayoutSupplementaryItem.h"

@implementation NSCollectionLayoutSupplementaryItem {
    NSCollectionLayoutSize *_suppLayoutSize;
    NSString *_elementKind;
    NSCollectionLayoutAnchor *_containerAnchor;
    NSCollectionLayoutAnchor *_itemAnchor;
    NSInteger _zIndex;
}
@synthesize zIndex = _zIndex;

+ (instancetype)supplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                                    elementKind:(NSString *)elementKind
                                containerAnchor:(NSCollectionLayoutAnchor *)containerAnchor
{
    return [self supplementaryItemWithLayoutSize:layoutSize elementKind:elementKind
                                 containerAnchor:containerAnchor itemAnchor:nil];
}

+ (instancetype)supplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                                    elementKind:(NSString *)elementKind
                                containerAnchor:(NSCollectionLayoutAnchor *)containerAnchor
                                     itemAnchor:(NSCollectionLayoutAnchor *)itemAnchor
{
    NSCollectionLayoutSupplementaryItem *s = [[self alloc] init];
    s->_suppLayoutSize = [layoutSize copy];
    s->_elementKind = [elementKind copy];
    s->_containerAnchor = containerAnchor;
    s->_itemAnchor = itemAnchor;
    s->_zIndex = 1;   /* measured default */
    return s;
}

- (NSCollectionLayoutSize *)layoutSize { return _suppLayoutSize; }
- (NSString *)elementKind { return _elementKind; }
- (NSCollectionLayoutAnchor *)containerAnchor { return _containerAnchor; }
- (NSCollectionLayoutAnchor *)itemAnchor { return _itemAnchor; }

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutSupplementaryItem *c =
        [[self class] supplementaryItemWithLayoutSize:_suppLayoutSize elementKind:_elementKind
                                      containerAnchor:_containerAnchor itemAnchor:_itemAnchor];
    c->_zIndex = _zIndex;
    c.contentInsets = self.contentInsets;
    c.edgeSpacing = self.edgeSpacing;
    return c;
}

@end
