/*
 * NSCollectionViewCompositionalLayoutConfiguration.m — behavioral-1:1 core.
 */

#import "NSCollectionViewCompositionalLayoutConfiguration.h"

@implementation NSCollectionViewCompositionalLayoutConfiguration {
    NSCollectionViewScrollDirection _scrollDirection;
    CGFloat _interSectionSpacing;
    NSArray *_boundarySupplementaryItems;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _scrollDirection = NSCollectionViewScrollDirectionVertical;  /* measured (0) */
        _boundarySupplementaryItems = @[];
    }
    return self;
}

- (NSCollectionViewScrollDirection)scrollDirection { return _scrollDirection; }
- (void)setScrollDirection:(NSCollectionViewScrollDirection)d { _scrollDirection = d; }
- (CGFloat)interSectionSpacing { return _interSectionSpacing; }
- (void)setInterSectionSpacing:(CGFloat)v { _interSectionSpacing = v; }
- (NSArray *)boundarySupplementaryItems { return _boundarySupplementaryItems; }
- (void)setBoundarySupplementaryItems:(NSArray *)a { _boundarySupplementaryItems = [a copy] ?: @[]; }

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionViewCompositionalLayoutConfiguration *c = [[[self class] alloc] init];
    c->_scrollDirection = _scrollDirection;
    c->_interSectionSpacing = _interSectionSpacing;
    c->_boundarySupplementaryItems = [_boundarySupplementaryItems copy];
    return c;
}

@end
