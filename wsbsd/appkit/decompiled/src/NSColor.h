/*
 * NSColor.h — 1:1 reimplementation (core). NSObject (class cluster).
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSColor : NSObject <NSCopying, NSSecureCoding, …>
 *   @property (Tq,R) type;                 // NSColorType
 *   @property (Td,R) redComponent/greenComponent/blueComponent;
 *   @property (Td,R) hueComponent/saturationComponent/brightnessComponent;
 *   @property (Td,R) whiteComponent/cyan/magenta/yellow/blackComponent;
 *   @property (Td,R) alphaComponent;
 *   @property (T@"NSColorSpace",R) colorSpace;
 *   @property (Tq,R) numberOfComponents;
 *   +colorWithRed:green:blue:alpha: +colorWithSRGBRed:… +colorWithWhite:alpha:
 *   +colorWithCalibratedRed:… +colorWithColorSpace:components:count:
 *   +whiteColor +blackColor +redColor … -colorWithAlphaComponent:
 *   -colorUsingColorSpace: -getRed:green:blue:alpha: -getHue:…
 *
 * NSColor is a class cluster: the `type` property distinguishes component-based,
 * pattern and catalog colors. This core implements the component-based path
 * fully (over NSColorSpace), with RGB/Gray models and exact RGB<->HSB
 * conversion. Component accessors raise when asked for a value the color's model
 * does not define — matching AppKit. Pattern colors, catalog/semantic/dynamic
 * colors (labelColor, controlAccentColor, appearance-reactive) are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSColorSpace.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSColorType) {
    NSColorTypeComponentBased = 0,
    NSColorTypePattern = 1,
    NSColorTypeCatalog = 2,
};

@interface NSColor : NSObject <NSCopying>

/* component-based constructors */
+ (NSColor *)colorWithColorSpace:(NSColorSpace *)space components:(const CGFloat *)components count:(NSInteger)count;
+ (NSColor *)colorWithSRGBRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (NSColor *)colorWithRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (NSColor *)colorWithCalibratedRed:(CGFloat)red green:(CGFloat)green blue:(CGFloat)blue alpha:(CGFloat)alpha;
+ (NSColor *)colorWithWhite:(CGFloat)white alpha:(CGFloat)alpha;
+ (NSColor *)colorWithCalibratedWhite:(CGFloat)white alpha:(CGFloat)alpha;
+ (NSColor *)colorWithHue:(CGFloat)hue saturation:(CGFloat)saturation brightness:(CGFloat)brightness alpha:(CGFloat)alpha;

/* named component-based colors */
+ (NSColor *)blackColor;
+ (NSColor *)whiteColor;
+ (NSColor *)redColor;
+ (NSColor *)greenColor;
+ (NSColor *)blueColor;
+ (NSColor *)yellowColor;
+ (NSColor *)cyanColor;
+ (NSColor *)magentaColor;
+ (NSColor *)grayColor;
+ (NSColor *)clearColor;

@property (readonly) NSColorType type;
@property (readonly) NSColorSpace *colorSpace;
@property (readonly) NSInteger numberOfComponents;

@property (readonly) CGFloat redComponent;
@property (readonly) CGFloat greenComponent;
@property (readonly) CGFloat blueComponent;
@property (readonly) CGFloat hueComponent;
@property (readonly) CGFloat saturationComponent;
@property (readonly) CGFloat brightnessComponent;
@property (readonly) CGFloat whiteComponent;
@property (readonly) CGFloat alphaComponent;

- (void)getComponents:(CGFloat *)components;
- (void)getRed:(nullable CGFloat *)red green:(nullable CGFloat *)green blue:(nullable CGFloat *)blue alpha:(nullable CGFloat *)alpha;
- (void)getWhite:(nullable CGFloat *)white alpha:(nullable CGFloat *)alpha;
- (void)getHue:(nullable CGFloat *)hue saturation:(nullable CGFloat *)saturation brightness:(nullable CGFloat *)brightness alpha:(nullable CGFloat *)alpha;

- (NSColor *)colorWithAlphaComponent:(CGFloat)alpha;
- (nullable NSColor *)colorUsingColorSpace:(NSColorSpace *)space;

@property (readonly) CGColorRef CGColor;

@end

NS_ASSUME_NONNULL_END
