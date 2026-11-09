/*
 * NSGradient.h — 1:1 reimplementation (core). NSObject <NSCopying, NSSecureCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSGradient : NSObject <NSCopying, NSSecureCoding, NSCoding> {
 *       _colors; _locations; _colorSpace;
 *   }
 *   @property (T@"NSColorSpace",N,R) colorSpace;
 *   @property (Tq,N,R) numberOfColorStops;
 *   @property (T^{CGGradient=},N,R) CGGradient;
 *   -initWithStartingColor:endingColor: -initWithColors:
 *   -initWithColors:atLocations:colorSpace: -getColor:location:atIndex:
 *   -interpolatedColorAtLocation: -draw…(context)
 *
 * A gradient is a list of colour stops (colors + normalised locations) in a
 * colour space. interpolatedColorAtLocation: and the stop accessors are exact;
 * the draw… methods need a graphics context and are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSColor.h"
#import "NSColorSpace.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSGradient : NSObject <NSCopying>

- (nullable instancetype)initWithStartingColor:(NSColor *)startingColor endingColor:(NSColor *)endingColor;
- (nullable instancetype)initWithColors:(NSArray<NSColor *> *)colorArray;
- (nullable instancetype)initWithColors:(NSArray<NSColor *> *)colorArray
                             atLocations:(nullable const CGFloat *)locations
                              colorSpace:(NSColorSpace *)colorSpace;

@property (readonly) NSColorSpace *colorSpace;
@property (readonly) NSInteger numberOfColorStops;

- (void)getColor:(NSColor * _Nullable * _Nullable)color location:(nullable CGFloat *)location atIndex:(NSInteger)index;
- (nullable NSColor *)interpolatedColorAtLocation:(CGFloat)location;

@end

NS_ASSUME_NONNULL_END
