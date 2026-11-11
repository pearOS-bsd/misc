/*
 * NSAccessibilityCustomRotor.h — 1:1 reimplementation of AppKit's
 * NSAccessibilityCustomRotor, a VoiceOver rotor an element vends.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSAccessibilityCustomRotor_interface.txt. Real ivars: _type,
 * _label, _itemSearchDelegate (weak), _itemLoadingDelegate (weak).
 *
 * initWithLabel:itemSearchDelegate: makes a Custom-type rotor;
 * initWithRotorType:itemSearchDelegate: makes a typed rotor with an empty label.
 * The actual rotor navigation (VoiceOver driving the search delegate) is the AX
 * client runtime = stage2; this is the value/config object.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol NSAccessibilityCustomRotorItemSearchDelegate, NSAccessibilityElementLoading;

typedef NS_ENUM(NSInteger, NSAccessibilityCustomRotorType) {
    NSAccessibilityCustomRotorTypeCustom        = 0,
    NSAccessibilityCustomRotorTypeAny           = 1,
    NSAccessibilityCustomRotorTypeAnnotation    = 2,
    NSAccessibilityCustomRotorTypeBoldText      = 3,
    NSAccessibilityCustomRotorTypeHeading       = 4,
    NSAccessibilityCustomRotorTypeHeadingLevel1 = 5,
    NSAccessibilityCustomRotorTypeHeadingLevel2 = 6,
    NSAccessibilityCustomRotorTypeHeadingLevel3 = 7,
    NSAccessibilityCustomRotorTypeHeadingLevel4 = 8,
    NSAccessibilityCustomRotorTypeHeadingLevel5 = 9,
    NSAccessibilityCustomRotorTypeHeadingLevel6 = 10,
    NSAccessibilityCustomRotorTypeImage         = 11,
    NSAccessibilityCustomRotorTypeItalicText    = 12,
    NSAccessibilityCustomRotorTypeLandmark      = 13,
    NSAccessibilityCustomRotorTypeLink          = 14,
    NSAccessibilityCustomRotorTypeList          = 15,
    NSAccessibilityCustomRotorTypeMisspelledWord = 16,
    NSAccessibilityCustomRotorTypeTable         = 17,
    NSAccessibilityCustomRotorTypeTextField     = 18,
    NSAccessibilityCustomRotorTypeUnderlinedText = 19,
    NSAccessibilityCustomRotorTypeVisitedLink   = 20,
};

@interface NSAccessibilityCustomRotor : NSObject

- (instancetype)initWithLabel:(NSString *)label itemSearchDelegate:(nullable id<NSAccessibilityCustomRotorItemSearchDelegate>)itemSearchDelegate;
- (instancetype)initWithRotorType:(NSAccessibilityCustomRotorType)rotorType itemSearchDelegate:(nullable id<NSAccessibilityCustomRotorItemSearchDelegate>)itemSearchDelegate;

@property NSAccessibilityCustomRotorType type;
@property (copy) NSString *label;
@property (nullable, weak) id<NSAccessibilityCustomRotorItemSearchDelegate> itemSearchDelegate;
@property (nullable, weak) id<NSAccessibilityElementLoading> itemLoadingDelegate;

@end

NS_ASSUME_NONNULL_END
