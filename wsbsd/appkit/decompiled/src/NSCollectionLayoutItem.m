/*
 * NSCollectionLayoutItem.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionLayoutItem.h"

const NSDirectionalEdgeInsets NSDirectionalEdgeInsetsZero = {0, 0, 0, 0};

@implementation NSCollectionLayoutItem {
    NSCollectionLayoutSize *_layoutSize;
    NSDirectionalEdgeInsets _contentInsets;
    NSCollectionLayoutEdgeSpacing *_edgeSpacing;
    NSArray *_supplementaryItems;
}

+ (instancetype)itemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
{
    return [self itemWithLayoutSize:layoutSize supplementaryItems:@[]];
}

+ (instancetype)itemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                 supplementaryItems:(NSArray *)supplementaryItems
{
    NSCollectionLayoutItem *i = [[self alloc] init];
    i->_layoutSize = [layoutSize copy];        /* measured: the size is copied */
    i->_supplementaryItems = [supplementaryItems copy] ?: @[];
    i->_contentInsets = NSDirectionalEdgeInsetsZero;
    return i;
}

- (NSCollectionLayoutSize *)layoutSize { return _layoutSize; }
- (NSDirectionalEdgeInsets)contentInsets { return _contentInsets; }
- (void)setContentInsets:(NSDirectionalEdgeInsets)insets { _contentInsets = insets; }
- (NSCollectionLayoutEdgeSpacing *)edgeSpacing { return _edgeSpacing; }
- (void)setEdgeSpacing:(NSCollectionLayoutEdgeSpacing *)e { _edgeSpacing = [e copy]; }
- (NSArray *)supplementaryItems { return _supplementaryItems; }

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutItem *c = [[self class] itemWithLayoutSize:_layoutSize supplementaryItems:_supplementaryItems];
    c->_contentInsets = _contentInsets;
    c->_edgeSpacing = [_edgeSpacing copy];
    return c;
}

@end
