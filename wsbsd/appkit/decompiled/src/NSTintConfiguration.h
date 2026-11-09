/*
 * NSTintConfiguration.h — 1:1 reimplementation (core). NSObject <NSCopying, NSSecureCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSTintConfiguration : NSObject <NSCopying, NSSecureCoding> {
 *       B _allowsAccentOverride;  q _type;  @"NSColor" _tintColor;
 *   }
 *   @property (T@"NSColor",R) baseTintColor;
 *   @property (T@"NSColor",R) equivalentContentTintColor;
 *   @property (TB,R) adaptsToUserAccentColor;
 *   +defaultTintConfiguration +monochromeTintConfiguration
 *   +tintConfigurationWithFixedColor: +tintConfigurationWithPreferredColor:
 *
 * How a control is tinted. default/preferred adapt to the user accent colour;
 * fixed/monochrome do not. baseTintColor is the configured colour (nil for
 * default/monochrome). The equivalent content tint colour derivation is stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTintConfiguration : NSObject <NSCopying>

@property (class, readonly, strong) NSTintConfiguration *defaultTintConfiguration;
@property (class, readonly, strong) NSTintConfiguration *monochromeTintConfiguration;
+ (instancetype)tintConfigurationWithFixedColor:(id)color;      /* NSColor */
+ (instancetype)tintConfigurationWithPreferredColor:(id)color;  /* NSColor */

@property (nullable, readonly) id baseTintColor;                /* NSColor */
@property (nullable, readonly) id equivalentContentTintColor;   /* NSColor */
@property (readonly) BOOL adaptsToUserAccentColor;

@end

NS_ASSUME_NONNULL_END
