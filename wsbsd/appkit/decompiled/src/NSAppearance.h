/*
 * NSAppearance.h — 1:1 reimplementation (core). NSObject <NSSecureCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSAppearance : NSObject <NSSecureCoding> {
 *       @"NSString" _name;  @"NSBundle" _bundle;
 *       ^{OpaqueCUIRendererRef} _coreUIRenderer;  @"CUICatalog" _coreUICatalog;
 *       @"NSColor" _tintColor; …
 *       b1 _allowsVibrancy; b1 _supportsWhitePointAdjustments; … (flag bits)
 *   }
 *   +appearanceNamed: +currentAppearance +currentDrawingAppearance
 *   -initWithAppearanceNamed:bundle: -name -allowsVibrancy
 *   -bestMatchFromAppearancesWithNames: -performAsCurrentDrawingAppearance:
 *
 * An appearance is identified by its name; the standard named appearances are
 * cached singletons. allowsVibrancy and the light/dark family drive
 * bestMatchFromAppearancesWithNames:. The CoreUI renderer / CUICatalog / tint
 * colour machinery is stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * NSAppearanceName NS_EXTENSIBLE_STRING_ENUM;

extern NSAppearanceName const NSAppearanceNameAqua;
extern NSAppearanceName const NSAppearanceNameDarkAqua;
extern NSAppearanceName const NSAppearanceNameVibrantLight;
extern NSAppearanceName const NSAppearanceNameVibrantDark;
extern NSAppearanceName const NSAppearanceNameAccessibilityHighContrastAqua;
extern NSAppearanceName const NSAppearanceNameAccessibilityHighContrastDarkAqua;

@interface NSAppearance : NSObject

- (nullable instancetype)initWithAppearanceNamed:(NSAppearanceName)name bundle:(nullable NSBundle *)bundle;
+ (nullable NSAppearance *)appearanceNamed:(NSAppearanceName)name;

@property (class, nullable, strong) NSAppearance *currentDrawingAppearance;
+ (nullable NSAppearance *)currentAppearance; /* deprecated alias */

@property (readonly) NSAppearanceName name;
@property (readonly) BOOL allowsVibrancy;

- (nullable NSAppearanceName)bestMatchFromAppearancesWithNames:(NSArray<NSAppearanceName> *)appearances;
- (void)performAsCurrentDrawingAppearance:(void (NS_NOESCAPE ^)(void))block;

@end

NS_ASSUME_NONNULL_END
