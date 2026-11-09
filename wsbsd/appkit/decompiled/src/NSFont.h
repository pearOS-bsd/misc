/*
 * NSFont.h — 1:1 reimplementation (core). NSObject <NSCopying, NSSecureCoding>.
 * Public AppKit API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSFont : NSObject <NSCopying, NSSecureCoding>
 *   @property (T@"NSString",R,C) fontName/familyName/displayName;
 *   @property (Td,R) pointSize/ascender/descender/leading/capHeight/xHeight
 *          /underlinePosition/underlineThickness/italicAngle;
 *   @property (TQ,R) numberOfGlyphs;  (T{CGRect},R) boundingRectForFont;
 *   +fontWithName:size: +systemFontOfSize: +boldSystemFontOfSize:
 *   +systemFontOfSize:weight: +fontWithDescriptor:size:
 *
 * NSFont wraps a CTFontRef: every metric is read from CoreText, so the wrapper
 * is exact. On BSD the CoreText backing is a separate port (stage2 for the
 * text engine itself); the NSFont-over-CTFont mapping here is 1:1.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreText/CoreText.h>

NS_ASSUME_NONNULL_BEGIN

typedef CGFloat NSFontWeight;

@interface NSFont : NSObject <NSCopying>

+ (nullable NSFont *)fontWithName:(NSString *)fontName size:(CGFloat)fontSize;
+ (NSFont *)systemFontOfSize:(CGFloat)fontSize;
+ (NSFont *)boldSystemFontOfSize:(CGFloat)fontSize;
+ (NSFont *)systemFontOfSize:(CGFloat)fontSize weight:(NSFontWeight)weight;
+ (nullable NSFont *)fontWithCTFont:(CTFontRef)ctFont;

@property (readonly, copy) NSString *fontName;
@property (readonly, copy) NSString *familyName;
@property (readonly, copy) NSString *displayName;
@property (readonly) CGFloat pointSize;

@property (readonly) CGFloat ascender;
@property (readonly) CGFloat descender;
@property (readonly) CGFloat leading;
@property (readonly) CGFloat capHeight;
@property (readonly) CGFloat xHeight;
@property (readonly) CGFloat underlinePosition;
@property (readonly) CGFloat underlineThickness;
@property (readonly) CGFloat italicAngle;
@property (readonly) NSUInteger numberOfGlyphs;
@property (readonly, getter=isFixedPitch) BOOL fixedPitch;
@property (readonly) CGRect boundingRectForFont;

@property (readonly) CTFontRef CTFont;

@end

NS_ASSUME_NONNULL_END
