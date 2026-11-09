/*
 * NSGradient.m — 1:1 (core). See NSGradient.h for the interface evidence.
 *
 * Stores the stop colours (_colors), their normalised locations (_locations)
 * and the colour space (_colorSpace, default sRGB per +defaultColorSpace).
 * interpolatedColorAtLocation: finds the bracketing pair of stops and linearly
 * interpolates each RGBA component, clamping below the first and above the last
 * stop — matching AppKit. The draw… methods (need an NSGraphicsContext) and the
 * CGGradient cache are stage2.
 */
#import "NSGradient.h"

@implementation NSGradient {
    NSArray<NSColor *> *_colors;
    NSMutableData *_locData;   /* CGFloat[count] */
    NSColorSpace *_colorSpace;
}

- (const CGFloat *)_locations { return (const CGFloat *)_locData.bytes; }

- (instancetype)initWithColors:(NSArray<NSColor *> *)colorArray
                   atLocations:(const CGFloat *)locations
                    colorSpace:(NSColorSpace *)colorSpace
{
    if (colorArray.count < 1) return nil;
    self = [super init];
    if (self) {
        _colorSpace = colorSpace ?: [NSColorSpace sRGBColorSpace];
        /* Convert every stop colour into the gradient colour space up front. */
        NSMutableArray<NSColor *> *cs = [NSMutableArray arrayWithCapacity:colorArray.count];
        for (NSColor *c in colorArray) {
            NSColor *conv = [c colorUsingColorSpace:_colorSpace] ?: c;
            [cs addObject:conv];
        }
        _colors = [cs copy];
        NSInteger n = cs.count;
        _locData = [NSMutableData dataWithLength:sizeof(CGFloat) * n];
        CGFloat *loc = (CGFloat *)_locData.mutableBytes;
        if (locations) {
            for (NSInteger i = 0; i < n; i++) loc[i] = locations[i];
        } else {
            /* evenly spaced 0..1 */
            for (NSInteger i = 0; i < n; i++) loc[i] = (n == 1) ? 0.0 : (CGFloat)i / (CGFloat)(n - 1);
        }
    }
    return self;
}

- (instancetype)initWithColors:(NSArray<NSColor *> *)colorArray
{
    return [self initWithColors:colorArray atLocations:NULL colorSpace:[NSColorSpace sRGBColorSpace]];
}

- (instancetype)initWithStartingColor:(NSColor *)startingColor endingColor:(NSColor *)endingColor
{
    if (!startingColor || !endingColor) return nil;
    CGFloat loc[2] = {0.0, 1.0};
    return [self initWithColors:@[startingColor, endingColor] atLocations:loc colorSpace:[NSColorSpace sRGBColorSpace]];
}

- (NSColorSpace *)colorSpace { return _colorSpace; }
- (NSInteger)numberOfColorStops { return _colors.count; }

- (void)getColor:(NSColor **)color location:(CGFloat *)location atIndex:(NSInteger)index
{
    if (index < 0 || index >= (NSInteger)_colors.count)
        [NSException raise:NSRangeException format:@"color stop index %ld out of range", (long)index];
    if (color) *color = _colors[index];
    if (location) *location = [self _locations][index];
}

- (NSColor *)interpolatedColorAtLocation:(CGFloat)location
{
    NSInteger n = _colors.count;
    if (n == 0) return nil;
    const CGFloat *loc = [self _locations];

    /* clamp outside the stop range */
    if (location <= loc[0]) return _colors[0];
    if (location >= loc[n - 1]) return _colors[n - 1];

    /* find the bracketing pair [i, i+1] */
    NSInteger i = 0;
    while (i < n - 1 && location > loc[i + 1]) i++;

    CGFloat lo = loc[i], hi = loc[i + 1];
    CGFloat t = (hi > lo) ? (location - lo) / (hi - lo) : 0.0;

    NSColor *c0 = _colors[i], *c1 = _colors[i + 1];
    /* interpolate in the gradient space; both stops already share it */
    if (_colorSpace.colorSpaceModel == NSColorSpaceModelRGB) {
        CGFloat r0,g0,b0,a0, r1,g1,b1,a1;
        [c0 getRed:&r0 green:&g0 blue:&b0 alpha:&a0];
        [c1 getRed:&r1 green:&g1 blue:&b1 alpha:&a1];
        return [NSColor colorWithColorSpace:_colorSpace
                                 components:(CGFloat[]){ r0 + (r1-r0)*t, g0 + (g1-g0)*t,
                                                         b0 + (b1-b0)*t, a0 + (a1-a0)*t }
                                      count:4];
    } else {
        /* gray (or other 1-channel) */
        CGFloat w0 = c0.whiteComponent, w1 = c1.whiteComponent;
        CGFloat a0 = c0.alphaComponent, a1 = c1.alphaComponent;
        return [NSColor colorWithColorSpace:_colorSpace
                                 components:(CGFloat[]){ w0 + (w1-w0)*t, a0 + (a1-a0)*t }
                                      count:2];
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[NSGradient alloc] initWithColors:_colors atLocations:[self _locations] colorSpace:_colorSpace];
}

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSGradient class]]) return NO;
    NSGradient *o = object;
    if (![o->_colorSpace isEqual:_colorSpace]) return NO;
    if (![o->_colors isEqualToArray:_colors]) return NO;
    return [o->_locData isEqualToData:_locData];
}

- (NSUInteger)hash { return _colors.count ^ _colorSpace.hash; }

@end
