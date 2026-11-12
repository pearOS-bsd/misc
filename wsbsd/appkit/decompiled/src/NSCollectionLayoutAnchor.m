/*
 * NSCollectionLayoutAnchor.m — behavioral-1:1 core. See the header.
 */

#import "NSCollectionLayoutAnchor.h"

@implementation NSCollectionLayoutAnchor {
    NSDirectionalRectEdge _edges;
    CGPoint _offset;
    BOOL _fractional;
}

+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges
{
    return [self layoutAnchorWithEdges:edges absoluteOffset:CGPointZero];
}

+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges absoluteOffset:(CGPoint)absoluteOffset
{
    NSCollectionLayoutAnchor *a = [[self alloc] init];
    a->_edges = edges;
    a->_offset = absoluteOffset;
    a->_fractional = NO;
    return a;
}

+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges fractionalOffset:(CGPoint)fractionalOffset
{
    NSCollectionLayoutAnchor *a = [[self alloc] init];
    a->_edges = edges;
    a->_offset = fractionalOffset;
    a->_fractional = YES;
    return a;
}

- (NSDirectionalRectEdge)edges { return _edges; }
- (CGPoint)offset { return _offset; }
- (BOOL)isAbsoluteOffset { return !_fractional; }   /* default is absolute (measured) */
- (BOOL)isFractionalOffset { return _fractional; }

- (id)copyWithZone:(NSZone *)zone
{
    return _fractional ? [[self class] layoutAnchorWithEdges:_edges fractionalOffset:_offset]
                       : [[self class] layoutAnchorWithEdges:_edges absoluteOffset:_offset];
}

@end
