/*
 * NSFontDescriptor.h — 1:1 reimplementation (core). NSObject <NSCopying, NSSecureCoding>.
 * Public AppKit API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSFontDescriptor : NSObject <NSCopying, NSSecureCoding> {
 *       @"NSMutableDictionary" _attributes;   // the single backing store
 *       @ _reserved1 … _reserved5;
 *   }
 *   @property (T@"NSString",R,C) postscriptName;
 *   @property (Td,R) pointSize;
 *   @property (TI,R) symbolicTraits;
 *   @property (T@"NSDictionary",R,C) fontAttributes;
 *   +fontDescriptorWithFontAttributes: +fontDescriptorWithName:size:
 *   -objectForKey: -fontDescriptorByAddingAttributes:
 *   -fontDescriptorWithSymbolicTraits: -fontDescriptorWithSymbolicTraits:mask:
 *
 * A font descriptor is a dictionary of attributes (the `_attributes` ivar).
 * NSFontDescriptor bridges to CTFontDescriptor and its attribute keys are the
 * CoreText constants (NSFontNameAttribute === kCTFontNameAttribute, etc.), so
 * this core uses the CT keys directly — exact. Matching against the installed
 * font database (-matchingFontDescriptorsWithMandatoryKeys:) is stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>

NS_ASSUME_NONNULL_BEGIN

/* Attribute keys — bridged to the CoreText constants (1:1). */
#define NSFontNameAttribute       ((NSString *)kCTFontNameAttribute)
#define NSFontSizeAttribute       ((NSString *)kCTFontSizeAttribute)
#define NSFontFamilyAttribute     ((NSString *)kCTFontFamilyNameAttribute)
#define NSFontTraitsAttribute     ((NSString *)kCTFontTraitsAttribute)
#define NSFontSymbolicTrait       ((NSString *)kCTFontSymbolicTrait)

typedef uint32_t NSFontSymbolicTraits;

@interface NSFontDescriptor : NSObject <NSCopying>

+ (NSFontDescriptor *)fontDescriptorWithFontAttributes:(nullable NSDictionary<NSString *, id> *)attributes;
+ (NSFontDescriptor *)fontDescriptorWithName:(NSString *)fontName size:(CGFloat)size;

@property (readonly, copy) NSString *postscriptName;
@property (readonly) CGFloat pointSize;
@property (readonly) NSFontSymbolicTraits symbolicTraits;
@property (readonly, copy) NSDictionary<NSString *, id> *fontAttributes;

- (nullable id)objectForKey:(NSString *)attribute;
- (NSFontDescriptor *)fontDescriptorByAddingAttributes:(NSDictionary<NSString *, id> *)attributes;
- (NSFontDescriptor *)fontDescriptorWithSymbolicTraits:(NSFontSymbolicTraits)symbolicTraits;
- (NSFontDescriptor *)fontDescriptorWithSize:(CGFloat)newPointSize;
- (NSFontDescriptor *)fontDescriptorWithFace:(NSString *)newFace;
- (NSFontDescriptor *)fontDescriptorWithFamily:(NSString *)newFamily;

@end

NS_ASSUME_NONNULL_END
