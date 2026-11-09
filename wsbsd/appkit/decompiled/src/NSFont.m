/*
 * NSFont.m — 1:1 (core). See NSFont.h for the interface evidence.
 *
 * Backed by a CTFontRef. Construction maps to CoreText:
 *   +fontWithName:size:       -> CTFontCreateWithName
 *   +systemFontOfSize:        -> CTFontCreateUIFontForLanguage(kCTFontUIFontSystem)
 *   +boldSystemFontOfSize:    -> kCTFontUIFontEmphasizedSystem
 *   +systemFontOfSize:weight: -> system font + weight trait via descriptor
 * Metrics delegate to the CTFontGet and CTFontCopy accessors:
 *   pointSize, ascender, descender, leading, capHeight, xHeight, underline
 *   position and thickness, italicAngle,
 *   numberOfGlyphs (CTFontGetGlyphCount), isFixedPitch (symbolic traits &
 *   kCTFontTraitMonoSpace), boundingRectForFont (CTFontGetBoundingBox),
 *   fontName (PostScript name), familyName, displayName (full name).
 */
#import "NSFont.h"

@implementation NSFont {
    CTFontRef _ctFont;
}

- (instancetype)_initWithCTFont:(CTFontRef)ctFont
{
    if (!ctFont) return nil;
    self = [super init];
    if (self) _ctFont = (CTFontRef)CFRetain(ctFont);
    return self;
}

- (void)dealloc { if (_ctFont) CFRelease(_ctFont); }

+ (NSFont *)fontWithCTFont:(CTFontRef)ctFont
{ return [[self alloc] _initWithCTFont:ctFont]; }

+ (NSFont *)fontWithName:(NSString *)fontName size:(CGFloat)fontSize
{
    if (fontSize <= 0) fontSize = 12.0;
    CTFontRef f = CTFontCreateWithName((__bridge CFStringRef)fontName, fontSize, NULL);
    if (!f) return nil;
    NSFont *r = [[self alloc] _initWithCTFont:f];
    CFRelease(f);
    return r;
}

+ (NSFont *)_uiFont:(CTFontUIFontType)type size:(CGFloat)size
{
    CTFontRef f = CTFontCreateUIFontForLanguage(type, size, NULL);
    NSFont *r = [[self alloc] _initWithCTFont:f];
    if (f) CFRelease(f);
    return r;
}

+ (NSFont *)systemFontOfSize:(CGFloat)fontSize
{ return [self _uiFont:kCTFontUIFontSystem size:(fontSize > 0 ? fontSize : 13.0)]; }

+ (NSFont *)boldSystemFontOfSize:(CGFloat)fontSize
{ return [self _uiFont:kCTFontUIFontEmphasizedSystem size:(fontSize > 0 ? fontSize : 13.0)]; }

+ (NSFont *)systemFontOfSize:(CGFloat)fontSize weight:(NSFontWeight)weight
{
    if (fontSize <= 0) fontSize = 13.0;
    /* Build a system-font descriptor carrying the requested weight trait. */
    NSDictionary *traits = @{ (__bridge NSString *)kCTFontWeightTrait: @(weight) };
    NSDictionary *attrs = @{ (__bridge NSString *)kCTFontTraitsAttribute: traits };
    CTFontRef base = CTFontCreateUIFontForLanguage(kCTFontUIFontSystem, fontSize, NULL);
    CTFontDescriptorRef desc = CTFontDescriptorCreateWithAttributes((__bridge CFDictionaryRef)attrs);
    CTFontRef f = CTFontCreateCopyWithAttributes(base, fontSize, NULL, desc);
    NSFont *r = [[self alloc] _initWithCTFont:(f ?: base)];
    if (f) CFRelease(f);
    CFRelease(base);
    CFRelease(desc);
    return r;
}

- (CTFontRef)CTFont { return _ctFont; }

- (NSString *)fontName { return (NSString *)CFBridgingRelease(CTFontCopyPostScriptName(_ctFont)); }
- (NSString *)familyName { return (NSString *)CFBridgingRelease(CTFontCopyFamilyName(_ctFont)); }
- (NSString *)displayName { return (NSString *)CFBridgingRelease(CTFontCopyFullName(_ctFont)); }
- (CGFloat)pointSize { return CTFontGetSize(_ctFont); }
- (CGFloat)ascender { return CTFontGetAscent(_ctFont); }
- (CGFloat)descender { return -CTFontGetDescent(_ctFont); } /* NSFont descender is negative */
- (CGFloat)leading { return CTFontGetLeading(_ctFont); }
- (CGFloat)capHeight { return CTFontGetCapHeight(_ctFont); }
- (CGFloat)xHeight { return CTFontGetXHeight(_ctFont); }
- (CGFloat)underlinePosition { return CTFontGetUnderlinePosition(_ctFont); }
- (CGFloat)underlineThickness { return CTFontGetUnderlineThickness(_ctFont); }
- (CGFloat)italicAngle { return CTFontGetSlantAngle(_ctFont); }
- (NSUInteger)numberOfGlyphs { return (NSUInteger)CTFontGetGlyphCount(_ctFont); }
- (CGRect)boundingRectForFont { return CTFontGetBoundingBox(_ctFont); }

- (BOOL)isFixedPitch
{
    CTFontSymbolicTraits t = CTFontGetSymbolicTraits(_ctFont);
    return (t & kCTFontTraitMonoSpace) != 0;
}

- (id)copyWithZone:(NSZone *)zone { return self; } /* fonts are immutable */

- (BOOL)isEqual:(id)object
{
    if (self == object) return YES;
    if (![object isKindOfClass:[NSFont class]]) return NO;
    NSFont *o = object;
    if (CTFontGetSize(_ctFont) != CTFontGetSize(o->_ctFont)) return NO;
    CFStringRef a = CTFontCopyPostScriptName(_ctFont);
    CFStringRef b = CTFontCopyPostScriptName(o->_ctFont);
    BOOL eq = (a && b && CFStringCompare(a, b, 0) == kCFCompareEqualTo);
    if (a) CFRelease(a); if (b) CFRelease(b);
    return eq;
}

- (NSUInteger)hash { return (NSUInteger)(CTFontGetSize(_ctFont) * 100.0) ^ self.fontName.hash; }

@end
