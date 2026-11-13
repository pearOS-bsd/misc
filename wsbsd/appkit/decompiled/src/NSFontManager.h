/*
 * NSFontManager.h — 1:1 reimplementation (core). NSObject <NSMenuItemValidation>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc` — see
 * evidence/-NSFontManager_interface.txt:
 *
 *   @interface NSFontManager : NSObject <NSMenuItemValidation> {
 *       NSFontPanel _panel; SEL _action; id _actionOrigin; id _target;
 *       NSFont _selFont;
 *       {_fmFlags="multipleFont"b1"disabled"b1"senderTagMode"b2 …} _fmFlags;
 *       id _delegate; id _collections;
 *   }
 *   + sharedFontManager
 *   -convertFont:toSize: / toHaveTrait: / toNotHaveTrait: / toFamily: / toFace:
 *   -traitsOfFont:  -weightOfFont:  -fontNamed:hasTraits:
 *   -selectedFont -setSelectedFont:isMultiple:  -target/-action/-isEnabled
 *
 * The shared manager mediates font conversions and drives the Format > Font
 * menu + Font Panel. This core implements the conversion algebra and the
 * target/action/menu-validation surface. The real font table, named
 * collections, NSFontPanel UI and delegate machinery are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSFont, NSMenuItem;

/* NSFontTraitMask (AppKit values). */
typedef NS_OPTIONS(NSUInteger, NSFontTraitMask) {
    NSItalicFontMask               = 0x00000001,
    NSBoldFontMask                 = 0x00000002,
    NSUnboldFontMask               = 0x00000004,
    NSNonStandardCharacterSetFontMask = 0x00000008,
    NSNarrowFontMask               = 0x00000010,
    NSExpandedFontMask             = 0x00000020,
    NSCondensedFontMask            = 0x00000040,
    NSSmallCapsFontMask            = 0x00000080,
    NSPosterFontMask               = 0x00000100,
    NSCompressedFontMask           = 0x00000200,
    NSFixedPitchFontMask           = 0x00000400,
    NSUnitalicFontMask             = 0x01000000,
};

@interface NSFontManager : NSObject

@property (class, readonly, strong) NSFontManager *sharedFontManager;

@property (readonly, getter=isMultiple) BOOL multiple;
@property (readonly, nullable, strong) NSFont *selectedFont;
@property (getter=isEnabled) BOOL enabled;
@property SEL action;
@property (nullable, weak) id target;

- (void)setSelectedFont:(NSFont *)fontObj isMultiple:(BOOL)flag;

/* Conversion algebra. */
- (NSFont *)convertFont:(NSFont *)fontObj;
- (NSFont *)convertFont:(NSFont *)fontObj toSize:(CGFloat)size;
- (nullable NSFont *)convertFont:(NSFont *)fontObj toFace:(NSString *)typeface;
- (NSFont *)convertFont:(NSFont *)fontObj toFamily:(NSString *)family;
- (NSFont *)convertFont:(NSFont *)fontObj toHaveTrait:(NSFontTraitMask)trait;
- (NSFont *)convertFont:(NSFont *)fontObj toNotHaveTrait:(NSFontTraitMask)trait;
- (NSFontTraitMask)convertFontTraits:(NSFontTraitMask)traits;

- (NSFontTraitMask)traitsOfFont:(NSFont *)fontObj;
- (NSInteger)weightOfFont:(NSFont *)fontObj;
- (BOOL)fontNamed:(NSString *)typeface hasTraits:(NSFontTraitMask)fontTraitMask;

- (BOOL)validateMenuItem:(NSMenuItem *)item;

@end

NS_ASSUME_NONNULL_END
