/*
 * NSColor.m — 1:1 (core). See NSColor.h for the interface evidence.
 *
 * Component-based path: a color stores its NSColorSpace and its component array
 * (colour channels + alpha). RGB<->HSB is the standard exact conversion. The
 * component accessors raise for a model that does not define them (e.g.
 * -redComponent on a gray color), matching AppKit's class-cluster behaviour.
 * CGColor is built from the backing CGColorSpace + components. Cross-model
 * conversion in -colorUsingColorSpace: is modelled for the RGB<->Gray cases
 * (luminance 0.299/0.587/0.114); arbitrary ICC conversion is stage2.
 */
#import "NSColor.h"

@implementation NSColor {
    NSColorSpace *_space;
    CGFloat _c[5];        /* up to 4 colour channels + alpha */
    NSInteger _nComponents; /* colour channels, excl. alpha */
}

- (instancetype)_initWithSpace:(NSColorSpace *)space components:(const CGFloat *)comps count:(NSInteger)count
{
    self = [super init];
    if (self) {
        _space = space;
        _nComponents = count - 1;       /* last entry is alpha */
        for (NSInteger i = 0; i < count && i < 5; i++) _c[i] = comps[i];
    }
    return self;
}

+ (NSColor *)colorWithColorSpace:(NSColorSpace *)space components:(const CGFloat *)components count:(NSInteger)count
{
    return [[self alloc] _initWithSpace:space components:components count:count];
}

+ (NSColor *)colorWithSRGBRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a
{
    CGFloat comps[4] = {r, g, b, a};
    return [self colorWithColorSpace:[NSColorSpace sRGBColorSpace] components:comps count:4];
}
+ (NSColor *)colorWithRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a
{ return [self colorWithSRGBRed:r green:g blue:b alpha:a]; }

+ (NSColor *)colorWithCalibratedRed:(CGFloat)r green:(CGFloat)g blue:(CGFloat)b alpha:(CGFloat)a
{
    CGFloat comps[4] = {r, g, b, a};
    return [self colorWithColorSpace:[NSColorSpace genericRGBColorSpace] components:comps count:4];
}

+ (NSColor *)colorWithWhite:(CGFloat)w alpha:(CGFloat)a
{
    CGFloat comps[2] = {w, a};
    return [self colorWithColorSpace:[NSColorSpace genericGrayColorSpace] components:comps count:2];
}
+ (NSColor *)colorWithCalibratedWhite:(CGFloat)w alpha:(CGFloat)a
{ return [self colorWithWhite:w alpha:a]; }

static void NSColorHSBToRGB(CGFloat h, CGFloat s, CGFloat v, CGFloat *r, CGFloat *g, CGFloat *b)
{
    if (s <= 0) { *r = *g = *b = v; return; }
    CGFloat hh = h * 6.0;
    if (hh >= 6.0) hh = 0.0;
    int i = (int)hh;
    CGFloat f = hh - i;
    CGFloat p = v * (1.0 - s);
    CGFloat q = v * (1.0 - s * f);
    CGFloat t = v * (1.0 - s * (1.0 - f));
    switch (i) {
        case 0: *r = v; *g = t; *b = p; break;
        case 1: *r = q; *g = v; *b = p; break;
        case 2: *r = p; *g = v; *b = t; break;
        case 3: *r = p; *g = q; *b = v; break;
        case 4: *r = t; *g = p; *b = v; break;
        default:*r = v; *g = p; *b = q; break;
    }
}

static void NSColorRGBToHSB(CGFloat r, CGFloat g, CGFloat b, CGFloat *h, CGFloat *s, CGFloat *v)
{
    CGFloat mx = fmax(r, fmax(g, b));
    CGFloat mn = fmin(r, fmin(g, b));
    CGFloat d = mx - mn;
    *v = mx;
    *s = (mx <= 0) ? 0 : d / mx;
    if (d <= 0) { *h = 0; return; }
    CGFloat hh;
    if (mx == r)      hh = (g - b) / d + (g < b ? 6.0 : 0.0);
    else if (mx == g) hh = (b - r) / d + 2.0;
    else              hh = (r - g) / d + 4.0;
    *h = hh / 6.0;
}

+ (NSColor *)colorWithHue:(CGFloat)hue saturation:(CGFloat)sat brightness:(CGFloat)bri alpha:(CGFloat)a
{
    CGFloat r, g, b;
    NSColorHSBToRGB(hue, sat, bri, &r, &g, &b);
    return [self colorWithSRGBRed:r green:g blue:b alpha:a];
}

+ (NSColor *)blackColor   { return [self colorWithWhite:0.0 alpha:1.0]; }
+ (NSColor *)whiteColor   { return [self colorWithWhite:1.0 alpha:1.0]; }
+ (NSColor *)grayColor    { return [self colorWithWhite:0.5 alpha:1.0]; }
+ (NSColor *)redColor     { return [self colorWithSRGBRed:1 green:0 blue:0 alpha:1]; }
+ (NSColor *)greenColor   { return [self colorWithSRGBRed:0 green:1 blue:0 alpha:1]; }
+ (NSColor *)blueColor    { return [self colorWithSRGBRed:0 green:0 blue:1 alpha:1]; }
+ (NSColor *)yellowColor  { return [self colorWithSRGBRed:1 green:1 blue:0 alpha:1]; }
+ (NSColor *)cyanColor    { return [self colorWithSRGBRed:0 green:1 blue:1 alpha:1]; }
+ (NSColor *)magentaColor { return [self colorWithSRGBRed:1 green:0 blue:1 alpha:1]; }
+ (NSColor *)clearColor   { return [self colorWithSRGBRed:0 green:0 blue:0 alpha:0]; }

- (NSColorType)type { return NSColorTypeComponentBased; }
- (NSColorSpace *)colorSpace { return _space; }
- (NSInteger)numberOfComponents { return _nComponents + 1; }

- (BOOL)_isRGB { return _space.colorSpaceModel == NSColorSpaceModelRGB; }
- (BOOL)_isGray { return _space.colorSpaceModel == NSColorSpaceModelGray; }

- (void)_requireRGB:(SEL)sel
{
    if (![self _isRGB])
        [NSException raise:NSGenericException
                    format:@"-%@ not valid for the %@ color %@; need -colorUsingColorSpace: first",
                           NSStringFromSelector(sel), @(_space.colorSpaceModel), self];
}

- (CGFloat)redComponent   { [self _requireRGB:_cmd]; return _c[0]; }
- (CGFloat)greenComponent { [self _requireRGB:_cmd]; return _c[1]; }
- (CGFloat)blueComponent  { [self _requireRGB:_cmd]; return _c[2]; }
- (CGFloat)alphaComponent { return _c[_nComponents]; }

- (CGFloat)whiteComponent
{
    if ([self _isGray]) return _c[0];
    /* RGB -> luminance */
    return 0.299 * _c[0] + 0.587 * _c[1] + 0.114 * _c[2];
}

- (CGFloat)hueComponent
{ [self _requireRGB:_cmd]; CGFloat h,s,v; NSColorRGBToHSB(_c[0],_c[1],_c[2],&h,&s,&v); return h; }
- (CGFloat)saturationComponent
{ [self _requireRGB:_cmd]; CGFloat h,s,v; NSColorRGBToHSB(_c[0],_c[1],_c[2],&h,&s,&v); return s; }
- (CGFloat)brightnessComponent
{ [self _requireRGB:_cmd]; CGFloat h,s,v; NSColorRGBToHSB(_c[0],_c[1],_c[2],&h,&s,&v); return v; }

- (void)getComponents:(CGFloat *)components
{ for (NSInteger i = 0; i <= _nComponents; i++) components[i] = _c[i]; }

- (void)getRed:(CGFloat *)r green:(CGFloat *)g blue:(CGFloat *)b alpha:(CGFloat *)a
{
    [self _requireRGB:_cmd];
    if (r) *r = _c[0]; if (g) *g = _c[1]; if (b) *b = _c[2]; if (a) *a = _c[_nComponents];
}
- (void)getWhite:(CGFloat *)w alpha:(CGFloat *)a
{ if (w) *w = self.whiteComponent; if (a) *a = _c[_nComponents]; }
- (void)getHue:(CGFloat *)h saturation:(CGFloat *)s brightness:(CGFloat *)b alpha:(CGFloat *)a
{
    [self _requireRGB:_cmd];
    CGFloat hh, ss, vv; NSColorRGBToHSB(_c[0], _c[1], _c[2], &hh, &ss, &vv);
    if (h) *h = hh; if (s) *s = ss; if (b) *b = vv; if (a) *a = _c[_nComponents];
}

- (NSColor *)colorWithAlphaComponent:(CGFloat)alpha
{
    CGFloat comps[5];
    for (NSInteger i = 0; i < _nComponents; i++) comps[i] = _c[i];
    comps[_nComponents] = alpha;
    return [NSColor colorWithColorSpace:_space components:comps count:_nComponents + 1];
}

- (NSColor *)colorUsingColorSpace:(NSColorSpace *)space
{
    if ([space isEqual:_space]) return self;
    NSColorSpaceModel to = space.colorSpaceModel, from = _space.colorSpaceModel;
    if (from == NSColorSpaceModelRGB && to == NSColorSpaceModelGray) {
        CGFloat comps[2] = { self.whiteComponent, _c[_nComponents] };
        return [NSColor colorWithColorSpace:space components:comps count:2];
    }
    if (from == NSColorSpaceModelGray && to == NSColorSpaceModelRGB) {
        CGFloat w = _c[0];
        CGFloat comps[4] = { w, w, w, _c[1] };
        return [NSColor colorWithColorSpace:space components:comps count:4];
    }
    if (from == to) {
        CGFloat comps[5];
        for (NSInteger i = 0; i <= _nComponents; i++) comps[i] = _c[i];
        return [NSColor colorWithColorSpace:space components:comps count:_nComponents + 1];
    }
    return nil; /* arbitrary ICC conversion is stage2 */
}

- (CGColorRef)CGColor
{
    CGColorSpaceRef cg = _space.CGColorSpace;
    CGFloat comps[5];
    for (NSInteger i = 0; i <= _nComponents; i++) comps[i] = _c[i];
    return (CGColorRef)CFAutorelease(CGColorCreate(cg, comps));
}

- (id)copyWithZone:(NSZone *)zone { return self; } /* colors are immutable */

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSColor class]]) return NO;
    NSColor *o = object;
    if (![o->_space isEqual:_space]) return NO;
    if (o->_nComponents != _nComponents) return NO;
    for (NSInteger i = 0; i <= _nComponents; i++) if (o->_c[i] != _c[i]) return NO;
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger h = (NSUInteger)_nComponents;
    for (NSInteger i = 0; i <= _nComponents; i++) h = h * 31 + (NSUInteger)(_c[i] * 255.0);
    return h;
}

@end
