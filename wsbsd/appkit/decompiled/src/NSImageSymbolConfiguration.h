/*
 * NSImageSymbolConfiguration.h — 1:1 reimplementation (core).
 * NSObject <NSCopying, NSSecureCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSImageSymbolConfiguration : NSObject <NSCopying, NSSecureCoding> {
 *       d _pointSize;  d _weight;  q _scale;  q _renderingStyle;
 *       @"NSArray" _colors;  B _prefersMulticolor;  …
 *   }
 *   @property (Td,R) pointSize;  (Td,R) weight;  (Tq,R) scale;
 *   +configurationWithPointSize:weight:(scale:) +configurationWithScale:
 *   +configurationPreferringMulticolor +configurationWithHierarchicalColor:
 *   -configurationByApplyingConfiguration:
 *
 * An SF Symbols rendering configuration (point size, weight, scale, colours).
 * configurationByApplyingConfiguration: layers another config on top, the newer
 * value winning where it is set. Resolving the config against a real symbol
 * image is stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSImageSymbolScale) {
    NSImageSymbolScaleUnspecified = 0,
    NSImageSymbolScaleSmall = 1,
    NSImageSymbolScaleMedium = 2,
    NSImageSymbolScaleLarge = 3,
};

@interface NSImageSymbolConfiguration : NSObject <NSCopying>

+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(CGFloat)weight;
+ (instancetype)configurationWithPointSize:(CGFloat)pointSize weight:(CGFloat)weight scale:(NSImageSymbolScale)scale;
+ (instancetype)configurationWithScale:(NSImageSymbolScale)scale;
+ (instancetype)configurationPreferringMulticolor;
+ (instancetype)configurationWithHierarchicalColor:(id)hierarchicalColor;

@property (readonly) CGFloat pointSize;
@property (readonly) CGFloat weight;
@property (readonly) NSImageSymbolScale scale;
@property (readonly) BOOL prefersMulticolor;
@property (nullable, readonly, copy) NSArray *colors;

- (NSImageSymbolConfiguration *)configurationByApplyingConfiguration:(NSImageSymbolConfiguration *)configuration;

@end

NS_ASSUME_NONNULL_END
