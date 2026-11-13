/*
 * NSFontManager.m — 1:1 (core). See NSFontManager.h for interface evidence.
 *
 * Our NSFont is identified by (fontName, pointSize), so the conversion algebra
 * works on the PostScript name: a trait is a "-Bold"/"-Italic"/"-BoldItalic"
 * face suffix on the family. This reproduces the observable behaviour of
 * convertFont:toHaveTrait:/toNotHaveTrait:/toSize:/toFamily:/toFace: and
 * traitsOfFont:/weightOfFont:/fontNamed:hasTraits: without the real font table.
 * The named collections, NSFontPanel UI and delegate notifications are stage2.
 */
#import "NSFontManager.h"
#import "NSFont.h"

@implementation NSFontManager {
    BOOL _multiple;
    NSFont *_selFont;
    BOOL _enabled;
    SEL _action;
    __weak id _target;
}

+ (NSFontManager *)sharedFontManager
{
    static NSFontManager *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ shared = [[self alloc] init]; });
    return shared;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _enabled = YES;
        _action = @selector(changeFont:);
    }
    return self;
}

- (BOOL)isMultiple { return _multiple; }
- (NSFont *)selectedFont { return _selFont; }
- (BOOL)isEnabled { return _enabled; }
- (void)setEnabled:(BOOL)enabled { _enabled = enabled; }
- (SEL)action { return _action; }
- (void)setAction:(SEL)action { _action = action; }
- (id)target { return _target; }
- (void)setTarget:(id)target { _target = target; }

- (void)setSelectedFont:(NSFont *)fontObj isMultiple:(BOOL)flag
{
    _selFont = fontObj;
    _multiple = flag;
}

/* ---- name helpers ---- */

static BOOL NameHasToken(NSString *name, NSString *tok)
{
    return [name rangeOfString:tok options:NSCaseInsensitiveSearch].location != NSNotFound;
}

/* Strip known face tokens, leaving the family base. */
static NSString *FamilyBase(NSString *fontName)
{
    NSString *base = fontName;
    for (NSString *tok in @[@"-BoldItalic", @"-BoldOblique", @"-Bold",
                            @"-Italic", @"-Oblique", @" Bold Italic",
                            @" Bold", @" Italic", @" Oblique"]) {
        NSRange r = [base rangeOfString:tok options:NSCaseInsensitiveSearch];
        if (r.location != NSNotFound)
            base = [base stringByReplacingCharactersInRange:r withString:@""];
    }
    return base;
}

/* Compose a PostScript face name from a family base + current trait set. */
static NSString *ComposeName(NSString *family, NSFontTraitMask traits)
{
    BOOL bold = (traits & NSBoldFontMask) != 0;
    BOOL ital = (traits & NSItalicFontMask) != 0;
    if (bold && ital) return [family stringByAppendingString:@"-BoldItalic"];
    if (bold)         return [family stringByAppendingString:@"-Bold"];
    if (ital)         return [family stringByAppendingString:@"-Italic"];
    return family;
}

- (NSFontTraitMask)traitsOfFont:(NSFont *)fontObj
{
    NSFontTraitMask t = 0;
    NSString *n = fontObj.fontName;
    if (NameHasToken(n, @"Bold"))                       t |= NSBoldFontMask;
    if (NameHasToken(n, @"Italic") || NameHasToken(n, @"Oblique")) t |= NSItalicFontMask;
    if (NameHasToken(n, @"Condensed") || NameHasToken(n, @"Narrow")) t |= NSCondensedFontMask;
    if (NameHasToken(n, @"Expanded"))                   t |= NSExpandedFontMask;
    if (!(t & NSBoldFontMask))                          t |= NSUnboldFontMask;
    if (!(t & NSItalicFontMask))                        t |= NSUnitalicFontMask;
    return t;
}

- (NSInteger)weightOfFont:(NSFont *)fontObj
{
    /* AppKit 1..14 scale; 5 = regular, 9 = bold. stage2: real per-face weight. */
    NSString *n = fontObj.fontName;
    if (NameHasToken(n, @"Black") || NameHasToken(n, @"Heavy")) return 11;
    if (NameHasToken(n, @"Bold"))      return 9;
    if (NameHasToken(n, @"Semibold") || NameHasToken(n, @"Medium")) return 7;
    if (NameHasToken(n, @"Light"))     return 3;
    if (NameHasToken(n, @"Thin") || NameHasToken(n, @"Ultralight")) return 2;
    return 5;
}

- (BOOL)fontNamed:(NSString *)typeface hasTraits:(NSFontTraitMask)fontTraitMask
{
    NSFont *f = [NSFont fontWithName:typeface size:12.0];
    if (!f) return NO;
    NSFontTraitMask have = [self traitsOfFont:f];
    /* Positive traits must all be present; "un" traits must be absent. */
    NSFontTraitMask positive = fontTraitMask & ~(NSUnboldFontMask | NSUnitalicFontMask);
    if ((have & positive) != positive) return NO;
    if ((fontTraitMask & NSUnboldFontMask) && (have & NSBoldFontMask)) return NO;
    if ((fontTraitMask & NSUnitalicFontMask) && (have & NSItalicFontMask)) return NO;
    return YES;
}

- (NSFontTraitMask)convertFontTraits:(NSFontTraitMask)traits
{
    /* Applying "un" masks clears the matching positive trait. */
    if (traits & NSUnboldFontMask)   traits &= ~NSBoldFontMask;
    if (traits & NSUnitalicFontMask) traits &= ~NSItalicFontMask;
    return traits;
}

- (NSFont *)convertFont:(NSFont *)fontObj { return fontObj; }

- (NSFont *)convertFont:(NSFont *)fontObj toSize:(CGFloat)size
{
    NSFont *f = [NSFont fontWithName:fontObj.fontName size:size];
    return f ?: fontObj;
}

- (NSFont *)convertFont:(NSFont *)fontObj toFamily:(NSString *)family
{
    NSFontTraitMask t = [self traitsOfFont:fontObj];
    NSString *name = ComposeName(family, t);
    NSFont *f = [NSFont fontWithName:name size:fontObj.pointSize];
    if (!f) f = [NSFont fontWithName:family size:fontObj.pointSize];
    return f ?: fontObj;
}

- (NSFont *)convertFont:(NSFont *)fontObj toFace:(NSString *)typeface
{
    NSFont *f = [NSFont fontWithName:typeface size:fontObj.pointSize];
    return f;  /* nil if the exact face does not exist */
}

- (NSFont *)convertFont:(NSFont *)fontObj toHaveTrait:(NSFontTraitMask)trait
{
    /* An "un" trait routes to removal of the matching positive trait. */
    if (trait & NSUnboldFontMask)   return [self convertFont:fontObj toNotHaveTrait:NSBoldFontMask];
    if (trait & NSUnitalicFontMask) return [self convertFont:fontObj toNotHaveTrait:NSItalicFontMask];

    NSFontTraitMask t = [self traitsOfFont:fontObj] | trait;
    NSString *name = ComposeName(FamilyBase(fontObj.fontName), t);
    NSFont *f = [NSFont fontWithName:name size:fontObj.pointSize];
    return f ?: fontObj;  /* unchanged if the trait variant does not exist */
}

- (NSFont *)convertFont:(NSFont *)fontObj toNotHaveTrait:(NSFontTraitMask)trait
{
    NSFontTraitMask t = [self traitsOfFont:fontObj] & ~trait;
    NSString *name = ComposeName(FamilyBase(fontObj.fontName), t);
    NSFont *f = [NSFont fontWithName:name size:fontObj.pointSize];
    if (!f) f = [NSFont fontWithName:FamilyBase(fontObj.fontName) size:fontObj.pointSize];
    return f ?: fontObj;
}

- (BOOL)validateMenuItem:(NSMenuItem *)item { return _enabled; }  /* stage2: per-action */

@end
