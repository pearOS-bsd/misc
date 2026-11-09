/*
 * NSGlyphInfo.h — 1:1 reimplementation (core). NSObject <NSCopying, NSSecureCoding>.
 * Public AppKit text API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSGlyphInfo : NSObject <NSCopying, NSSecureCoding> {
 *       @"NSString" _baseString;
 *   }
 *   +glyphInfoWithCharacterIdentifier:collection:baseString:
 *   +glyphInfoWithGlyphName:forFont:baseString:  +glyphInfoWithCGGlyph:forFont:baseString:
 *   -baseString -characterIdentifier -characterCollection -glyphName
 *
 * Pins a specific glyph to a run of text. The CID+collection and glyph-name
 * constructors are modelled here; the font-based constructors that resolve a
 * CGGlyph through a CTFont are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSCharacterCollection) {
    NSIdentityMappingCharacterCollection = 0,
    NSAdobeCNS1CharacterCollection = 1,
    NSAdobeGB1CharacterCollection = 2,
    NSAdobeJapan1CharacterCollection = 3,
    NSAdobeJapan2CharacterCollection = 4,
    NSAdobeKorea1CharacterCollection = 5,
};

@interface NSGlyphInfo : NSObject <NSCopying>

+ (nullable NSGlyphInfo *)glyphInfoWithCharacterIdentifier:(NSUInteger)cid
                                                collection:(NSCharacterCollection)characterCollection
                                                baseString:(NSString *)string;
+ (nullable NSGlyphInfo *)glyphInfoWithGlyphName:(NSString *)glyphName
                                         forFont:(nullable id)font
                                      baseString:(NSString *)string;

@property (readonly, copy) NSString *baseString;
@property (readonly) NSUInteger characterIdentifier;
@property (readonly) NSCharacterCollection characterCollection;
@property (nullable, readonly, copy) NSString *glyphName;

@end

NS_ASSUME_NONNULL_END
