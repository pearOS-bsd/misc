/*
 * NSTokenFieldCell.h — 1:1 reimplementation (core). NSTextFieldCell subclass.
 * Evidence ../evidence/token: tokenStyle = flags @0x730 bits 0-3 (setter accepts
 * 0..4 and 10..12, else 0), completionDelay = double @0x73c, tokenizingCharacterSet
 * @0x734 (nil -> the default set).
 */
#import "NSTextFieldCell.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSTokenStyle) {
    NSTokenStyleDefault = 0,
    NSTokenStyleNone = 1,
    NSTokenStyleRounded = 2,
    NSTokenStyleSquared = 3,
    NSTokenStylePlainSquared = 4,
};

@interface NSTokenFieldCell : NSTextFieldCell
@property NSTokenStyle tokenStyle;
@property NSTimeInterval completionDelay;
@property (null_resettable, copy) NSCharacterSet *tokenizingCharacterSet;
@end

NS_ASSUME_NONNULL_END
