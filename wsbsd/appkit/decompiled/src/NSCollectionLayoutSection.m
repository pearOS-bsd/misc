/*
 * NSCollectionLayoutSection.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionLayoutSection.h"

@implementation NSCollectionLayoutSection {
    NSCollectionLayoutGroup *_group;
    NSDirectionalEdgeInsets _contentInsets;
    CGFloat _interGroupSpacing;
    NSCollectionLayoutSectionOrthogonalScrollingBehavior _ortho;
    BOOL _supplementariesFollowContentInsets;
    NSArray *_boundarySupplementaryItems;
    NSArray *_decorationItems;
}

+ (instancetype)sectionWithGroup:(NSCollectionLayoutGroup *)group
{
    NSCollectionLayoutSection *s = [[self alloc] init];
    s->_group = [group copy];
    s->_contentInsets = NSDirectionalEdgeInsetsZero;
    s->_supplementariesFollowContentInsets = YES;   /* measured */
    s->_boundarySupplementaryItems = @[];
    s->_decorationItems = @[];
    return s;
}

- (NSDirectionalEdgeInsets)contentInsets { return _contentInsets; }
- (void)setContentInsets:(NSDirectionalEdgeInsets)i { _contentInsets = i; }
- (CGFloat)interGroupSpacing { return _interGroupSpacing; }
- (void)setInterGroupSpacing:(CGFloat)v { _interGroupSpacing = v; }
- (NSCollectionLayoutSectionOrthogonalScrollingBehavior)orthogonalScrollingBehavior { return _ortho; }
- (void)setOrthogonalScrollingBehavior:(NSCollectionLayoutSectionOrthogonalScrollingBehavior)b { _ortho = b; }
- (BOOL)supplementariesFollowContentInsets { return _supplementariesFollowContentInsets; }
- (void)setSupplementariesFollowContentInsets:(BOOL)v { _supplementariesFollowContentInsets = v; }
- (NSArray *)boundarySupplementaryItems { return _boundarySupplementaryItems; }
- (void)setBoundarySupplementaryItems:(NSArray *)a { _boundarySupplementaryItems = [a copy] ?: @[]; }
- (NSArray *)decorationItems { return _decorationItems; }
- (void)setDecorationItems:(NSArray *)a { _decorationItems = [a copy] ?: @[]; }

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutSection *c = [[self class] sectionWithGroup:_group];
    c->_contentInsets = _contentInsets;
    c->_interGroupSpacing = _interGroupSpacing;
    c->_ortho = _ortho;
    c->_supplementariesFollowContentInsets = _supplementariesFollowContentInsets;
    c->_boundarySupplementaryItems = [_boundarySupplementaryItems copy];
    c->_decorationItems = [_decorationItems copy];
    return c;
}

@end
