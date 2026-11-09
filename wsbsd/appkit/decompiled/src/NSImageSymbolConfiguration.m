/*
 * NSImageSymbolConfiguration.m — 1:1 (core). See the header for the evidence.
 *
 * Stores point size, weight, scale, colours and the multicolor flag. The
 * factories leave unmentioned fields at their unspecified defaults (0 / Unspecified
 * / nil). configurationByApplyingConfiguration: layers another config on top of
 * the receiver: each field the other config specifies (nonzero size/weight,
 * non-Unspecified scale, non-nil colours, multicolor YES) overrides, the rest
 * are kept. Resolving against a symbol image is stage2.
 */
#import "NSImageSymbolConfiguration.h"

@implementation NSImageSymbolConfiguration {
    CGFloat _pointSize;
    CGFloat _weight;
    NSImageSymbolScale _scale;
    BOOL _prefersMulticolor;
    NSArray *_colors;
}

+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(CGFloat)weight
{
    return [self configurationWithPointSize:pointSize weight:weight scale:NSImageSymbolScaleUnspecified];
}
+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(CGFloat)weight scale:(NSImageSymbolScale)scale
{
    NSImageSymbolConfiguration *c = [[self alloc] init];
    c->_pointSize = pointSize; c->_weight = weight; c->_scale = scale;
    return c;
}
+ (instancetype)configurationWithScale:(NSImageSymbolScale)scale
{
    NSImageSymbolConfiguration *c = [[self alloc] init];
    c->_scale = scale;
    return c;
}
+ (instancetype)configurationPreferringMulticolor
{
    NSImageSymbolConfiguration *c = [[self alloc] init];
    c->_prefersMulticolor = YES;
    return c;
}
+ (instancetype)configurationWithHierarchicalColor:(id)hierarchicalColor
{
    NSImageSymbolConfiguration *c = [[self alloc] init];
    if (hierarchicalColor) c->_colors = @[ hierarchicalColor ];
    return c;
}

- (CGFloat)pointSize { return _pointSize; }
- (CGFloat)weight { return _weight; }
- (NSImageSymbolScale)scale { return _scale; }
- (BOOL)prefersMulticolor { return _prefersMulticolor; }
- (NSArray *)colors { return _colors; }

- (NSImageSymbolConfiguration *)configurationByApplyingConfiguration:(NSImageSymbolConfiguration *)other
{
    NSImageSymbolConfiguration *c = [self copy];
    if (!other) return c;
    if (other->_pointSize != 0) c->_pointSize = other->_pointSize;
    if (other->_weight != 0) c->_weight = other->_weight;
    if (other->_scale != NSImageSymbolScaleUnspecified) c->_scale = other->_scale;
    if (other->_colors) c->_colors = [other->_colors copy];
    if (other->_prefersMulticolor) c->_prefersMulticolor = YES;
    return c;
}

- (id)copyWithZone:(NSZone *)zone
{
    NSImageSymbolConfiguration *c = [[NSImageSymbolConfiguration alloc] init];
    c->_pointSize = _pointSize; c->_weight = _weight; c->_scale = _scale;
    c->_prefersMulticolor = _prefersMulticolor; c->_colors = [_colors copy];
    return c;
}

@end
