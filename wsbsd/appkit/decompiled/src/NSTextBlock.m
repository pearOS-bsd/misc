/*
 * NSTextBlock.m — 1:1 (core). See NSTextBlock.h for the interface evidence.
 *
 * Dimensions are stored as (value, type) keyed by the dimension; layer widths
 * as (value, type) keyed by (layer, edge). setWidth:type:forLayer: sets all four
 * edges. contentWidth maps to the NSTextBlockWidth dimension. Defaults are 0 /
 * Absolute. The block layout and drawing (fill/stroke of the three layers) are
 * stage2.
 */
#import "NSTextBlock.h"

@implementation NSTextBlock {
    NSMutableDictionary<NSNumber *, NSArray *> *_dims;    /* dim -> @[value, type] */
    NSMutableDictionary<NSNumber *, NSArray *> *_layers;  /* layer*4+edge -> @[value, type] */
    NSTextBlockVerticalAlignment _verticalAlignment;
    id _backgroundColor;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _dims = [NSMutableDictionary dictionary]; _layers = [NSMutableDictionary dictionary]; }
    return self;
}

- (void)setValue:(CGFloat)val type:(NSTextBlockValueType)type forDimension:(NSTextBlockDimension)dimension
{
    _dims[@(dimension)] = @[ @(val), @(type) ];
}
- (CGFloat)valueForDimension:(NSTextBlockDimension)dimension
{
    NSArray *p = _dims[@(dimension)];
    return p ? [p[0] doubleValue] : 0.0;
}
- (NSTextBlockValueType)valueTypeForDimension:(NSTextBlockDimension)dimension
{
    NSArray *p = _dims[@(dimension)];
    return p ? [p[1] unsignedIntegerValue] : NSTextBlockAbsoluteValueType;
}

- (void)setContentWidth:(CGFloat)val type:(NSTextBlockValueType)type
{
    [self setValue:val type:type forDimension:NSTextBlockWidth];
}
- (CGFloat)contentWidth { return [self valueForDimension:NSTextBlockWidth]; }
- (NSTextBlockValueType)contentWidthValueType { return [self valueTypeForDimension:NSTextBlockWidth]; }

static NSNumber *NSTextBlockLayerKey(NSTextBlockLayer layer, NSRectEdge edge)
{
    return @(((NSInteger)layer + 1) * 4 + (NSInteger)edge);  /* +1 so Padding (-1) stays non-negative */
}

- (void)setWidth:(CGFloat)val type:(NSTextBlockValueType)type forLayer:(NSTextBlockLayer)layer edge:(NSRectEdge)edge
{
    _layers[NSTextBlockLayerKey(layer, edge)] = @[ @(val), @(type) ];
}
- (void)setWidth:(CGFloat)val type:(NSTextBlockValueType)type forLayer:(NSTextBlockLayer)layer
{
    for (NSRectEdge e = NSMinXEdge; e <= NSMaxYEdge; e++)
        [self setWidth:val type:type forLayer:layer edge:e];
}
- (CGFloat)widthForLayer:(NSTextBlockLayer)layer edge:(NSRectEdge)edge
{
    NSArray *p = _layers[NSTextBlockLayerKey(layer, edge)];
    return p ? [p[0] doubleValue] : 0.0;
}
- (NSTextBlockValueType)widthValueTypeForLayer:(NSTextBlockLayer)layer edge:(NSRectEdge)edge
{
    NSArray *p = _layers[NSTextBlockLayerKey(layer, edge)];
    return p ? [p[1] unsignedIntegerValue] : NSTextBlockAbsoluteValueType;
}

- (NSTextBlockVerticalAlignment)verticalAlignment { return _verticalAlignment; }
- (void)setVerticalAlignment:(NSTextBlockVerticalAlignment)v { _verticalAlignment = v; }
- (id)backgroundColor { return _backgroundColor; }
- (void)setBackgroundColor:(id)v { _backgroundColor = v; }

- (id)copyWithZone:(NSZone *)zone
{
    NSTextBlock *c = [[[self class] alloc] init];   /* polymorphic so subclasses copy as themselves */
    c->_dims = [_dims mutableCopy];
    c->_layers = [_layers mutableCopy];
    c->_verticalAlignment = _verticalAlignment;
    c->_backgroundColor = _backgroundColor;
    return c;
}

@end
