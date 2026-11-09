/*
 * NSTextAlternatives.h — 1:1 reimplementation (core). NSObject <NSSecureCoding>.
 * Public AppKit text API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSTextAlternatives : NSObject <NSSecureCoding> {
 *       @"NSString" _primaryString;  @"NSArray" _alternativeStrings;
 *       B _isLowConfidence;
 *   }
 *   @property (TB,V_isLowConfidence) isLowConfidence;
 *   @property (T@"NSString",R,C) primaryString;
 *   @property (T@"NSArray",R,C) alternativeStrings;
 *
 * A primary string plus a list of alternative spellings (as attached to text by
 * autocorrection). The core stores the values; the NSTextAlternativesSelected
 * notification posted when the user picks one is stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTextAlternatives : NSObject

- (instancetype)initWithPrimaryString:(NSString *)primaryString
                   alternativeStrings:(NSArray<NSString *> *)alternativeStrings;

@property (readonly, copy) NSString *primaryString;
@property (readonly, copy) NSArray<NSString *> *alternativeStrings;
@property (getter=isLowConfidence) BOOL lowConfidence;

@end

NS_ASSUME_NONNULL_END
