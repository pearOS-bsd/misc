/*
 * NSShadow.m — 1:1 (core). See NSShadow.h for the interface evidence.
 *
 * Stores offset (CGSize), blur radius and colour. Defaults: offset {0,0},
 * blur 0, colour nil (AppKit draws no shadow until a colour is set). -set and
 * -applyToGraphicsContext: install the shadow on the current / given graphics
 * context (CGContextSetShadowWithColor) and are stage2 — no context here.
 */
#import "NSShadow.h"

@implementation NSShadow {
    NSUInteger _shadowFlags;       /* _shadowFlags */
    CGSize _shadowOffset;
    CGFloat _shadowBlurRadius;
    NSColor *_shadowColor;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _shadowOffset = CGSizeMake(0, 0);
        _shadowBlurRadius = 0.0;
        _shadowColor = nil;
    }
    return self;
}

- (instancetype)initWithShadow:(NSShadow *)shadow
{
    self = [self init];
    if (self && shadow) {
        _shadowOffset = shadow->_shadowOffset;
        _shadowBlurRadius = shadow->_shadowBlurRadius;
        _shadowColor = [shadow->_shadowColor copy];
        _shadowFlags = shadow->_shadowFlags;
    }
    return self;
}

- (CGSize)shadowOffset { return _shadowOffset; }
- (void)setShadowOffset:(CGSize)v { _shadowOffset = v; }
- (CGFloat)shadowBlurRadius { return _shadowBlurRadius; }
- (void)setShadowBlurRadius:(CGFloat)v { _shadowBlurRadius = v; }
- (NSColor *)shadowColor { return _shadowColor; }
- (void)setShadowColor:(NSColor *)v { _shadowColor = [v copy]; }

- (id)copyWithZone:(NSZone *)zone { return [[NSShadow alloc] initWithShadow:self]; }

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSShadow class]]) return NO;
    NSShadow *o = object;
    if (_shadowOffset.width != o->_shadowOffset.width ||
        _shadowOffset.height != o->_shadowOffset.height) return NO;
    if (_shadowBlurRadius != o->_shadowBlurRadius) return NO;
    if (_shadowColor != o->_shadowColor && ![_shadowColor isEqual:o->_shadowColor]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    return (NSUInteger)(_shadowOffset.width * 1000.0) ^
           (NSUInteger)(_shadowOffset.height * 1000.0) ^
           (NSUInteger)(_shadowBlurRadius * 1000.0) ^ _shadowColor.hash;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"%@ {offset:{%g, %g} blur:%g color:%@}",
            [super description], _shadowOffset.width, _shadowOffset.height,
            _shadowBlurRadius, _shadowColor];
}

@end
