/*
 * NSCollectionLayoutBoundarySupplementaryItem.m — behavioral-1:1 core. See header.
 */

#import "NSCollectionLayoutBoundarySupplementaryItem.h"

@implementation NSCollectionLayoutBoundarySupplementaryItem {
    NSCollectionLayoutSize *_bLayoutSize;
    NSString *_bElementKind;
    NSRectAlignment _alignment;
    CGPoint _offset;
    BOOL _extendsBoundary;
    BOOL _pinToVisibleBounds;
}

+ (instancetype)boundarySupplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                                            elementKind:(NSString *)elementKind
                                              alignment:(NSRectAlignment)alignment
{
    return [self boundarySupplementaryItemWithLayoutSize:layoutSize elementKind:elementKind
                                               alignment:alignment absoluteOffset:CGPointZero];
}

+ (instancetype)boundarySupplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                                            elementKind:(NSString *)elementKind
                                              alignment:(NSRectAlignment)alignment
                                         absoluteOffset:(CGPoint)absoluteOffset
{
    NSCollectionLayoutBoundarySupplementaryItem *b = [[self alloc] init];
    b->_bLayoutSize = [layoutSize copy];
    b->_bElementKind = [elementKind copy];
    b->_alignment = alignment;
    b->_offset = absoluteOffset;
    b->_extendsBoundary = YES;     /* measured */
    b->_pinToVisibleBounds = NO;   /* measured */
    b.zIndex = 1;                  /* measured */
    return b;
}

- (NSCollectionLayoutSize *)layoutSize { return _bLayoutSize; }
- (NSString *)elementKind { return _bElementKind; }
- (NSRectAlignment)alignment { return _alignment; }
- (CGPoint)offset { return _offset; }
- (BOOL)extendsBoundary { return _extendsBoundary; }
- (void)setExtendsBoundary:(BOOL)v { _extendsBoundary = v; }
- (BOOL)pinToVisibleBounds { return _pinToVisibleBounds; }
- (void)setPinToVisibleBounds:(BOOL)v { _pinToVisibleBounds = v; }

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionLayoutBoundarySupplementaryItem *c =
        [[self class] boundarySupplementaryItemWithLayoutSize:_bLayoutSize elementKind:_bElementKind
                                                    alignment:_alignment absoluteOffset:_offset];
    c->_extendsBoundary = _extendsBoundary;
    c->_pinToVisibleBounds = _pinToVisibleBounds;
    c.zIndex = self.zIndex;
    return c;
}

@end
