/*
 * NSCollectionViewLayoutAttributes.m — 1:1 (core). See header for the evidence.
 *
 * frame is stored; center/bounds/size are derived and kept consistent:
 *   center = (frame.midX, frame.midY),  bounds = {0,0,frame.size},
 *   setCenter: moves the frame keeping its size,
 *   setBounds:/setSize: resize the frame keeping its center.
 * alpha defaults to 1, zIndex to 0. The 3D transform and the non-item element
 * kinds are stage2.
 */
#import "NSCollectionViewLayoutAttributes.h"

@implementation NSCollectionViewLayoutAttributes {
    CGRect _frame;
    CGFloat _alpha;
    NSInteger _zIndex;
    BOOL _hidden;
    BOOL _floating;
    NSIndexPath *_indexPath;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _frame = CGRectZero; _alpha = 1.0; }
    return self;
}

+ (instancetype)layoutAttributesForItemWithIndexPath:(NSIndexPath *)indexPath
{
    NSCollectionViewLayoutAttributes *a = [[self alloc] init];
    a->_indexPath = indexPath;
    return a;
}

- (CGRect)frame { return _frame; }
- (void)setFrame:(CGRect)frame { _frame = frame; }

- (CGSize)size { return _frame.size; }
- (void)setSize:(CGSize)size
{
    CGPoint c = self.center;
    _frame.size = size;
    self.center = c;   /* keep the center fixed while resizing */
}

- (CGRect)bounds { return CGRectMake(0, 0, _frame.size.width, _frame.size.height); }
- (void)setBounds:(CGRect)bounds { [self setSize:bounds.size]; }

- (CGPoint)center
{
    return CGPointMake(CGRectGetMidX(_frame), CGRectGetMidY(_frame));
}
- (void)setCenter:(CGPoint)center
{
    _frame.origin.x = center.x - _frame.size.width / 2.0;
    _frame.origin.y = center.y - _frame.size.height / 2.0;
}

- (CGFloat)alpha { return _alpha; }
- (void)setAlpha:(CGFloat)v { _alpha = v; }
- (NSInteger)zIndex { return _zIndex; }
- (void)setZIndex:(NSInteger)v { _zIndex = v; }
- (BOOL)isHidden { return _hidden; }
- (void)setHidden:(BOOL)v { _hidden = v; }
- (BOOL)isFloating { return _floating; }
- (void)setFloating:(BOOL)v { _floating = v; }
- (NSIndexPath *)indexPath { return _indexPath; }
- (void)setIndexPath:(NSIndexPath *)v { _indexPath = v; }

- (id)copyWithZone:(NSZone *)zone
{
    NSCollectionViewLayoutAttributes *c = [[NSCollectionViewLayoutAttributes alloc] init];
    c->_frame = _frame; c->_alpha = _alpha; c->_zIndex = _zIndex;
    c->_hidden = _hidden; c->_floating = _floating; c->_indexPath = _indexPath;
    return c;
}

@end
