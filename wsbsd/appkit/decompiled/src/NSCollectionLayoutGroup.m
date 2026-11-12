/*
 * NSCollectionLayoutGroup.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionLayoutGroup.h"

typedef NS_ENUM(NSInteger, NSCollectionLayoutGroupAxis) { kHorizontal = 0, kVertical = 1, kCustom = 2 };

@implementation NSCollectionLayoutGroup {
    NSCollectionLayoutSize *_groupLayoutSize;
    NSArray<NSCollectionLayoutItem *> *_subitems;
    NSCollectionLayoutSpacing *_interItemSpacing;
    NSCollectionLayoutGroupAxis _axis;
}

+ (instancetype)_groupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                            subitems:(NSArray *)subitems
                                axis:(NSCollectionLayoutGroupAxis)axis
{
    NSCollectionLayoutGroup *g = [[self alloc] init];
    g->_groupLayoutSize = [layoutSize copy];
    g->_subitems = [subitems copy] ?: @[];
    g->_axis = axis;
    return g;
}

+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize subitems:(NSArray *)subitems
{ return [self _groupWithLayoutSize:layoutSize subitems:subitems axis:kHorizontal]; }

+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize subitems:(NSArray *)subitems
{ return [self _groupWithLayoutSize:layoutSize subitems:subitems axis:kVertical]; }

/* the group carries its own size (overrides the NSCollectionLayoutItem slot). */
- (NSCollectionLayoutSize *)layoutSize { return _groupLayoutSize; }
- (NSArray<NSCollectionLayoutItem *> *)subitems { return _subitems; }
- (NSCollectionLayoutSpacing *)interItemSpacing { return _interItemSpacing; }
- (void)setInterItemSpacing:(NSCollectionLayoutSpacing *)s { _interItemSpacing = [s copy]; }

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutGroup *c = [[self class] _groupWithLayoutSize:_groupLayoutSize subitems:_subitems axis:_axis];
    c.contentInsets = self.contentInsets;
    c.edgeSpacing = self.edgeSpacing;
    c->_interItemSpacing = [_interItemSpacing copy];
    return c;
}

@end
