/*
 * NSDatePickerCell.h — 1:1 reimplementation (core). NSActionCell subclass.
 * Evidence ../evidence/date: minDate @0x2c4, _dpFlags @0x2cc (datePickerMode =
 * bits 19-20, datePickerStyle = bits 16-18); setDatePickerMode: validates <= 1.
 * dateValue is kept as a plain NSDate (shipping routes via NSCell contents — stage2).
 */
#import "NSActionCell.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSDatePickerMode) {
    NSSingleDateMode = 0,
    NSRangeDateMode = 1,
};
typedef NS_ENUM(NSUInteger, NSDatePickerStyle) {
    NSTextFieldAndStepperDatePickerStyle = 0,
    NSClockAndCalendarDatePickerStyle = 1,
    NSTextFieldDatePickerStyle = 2,
};

@interface NSDatePickerCell : NSActionCell
@property (nullable, copy) NSDate *dateValue;
@property (nullable, copy) NSDate *minDate;
@property (nullable, copy) NSDate *maxDate;
@property NSDatePickerMode datePickerMode;
@property NSDatePickerStyle datePickerStyle;
@end

NS_ASSUME_NONNULL_END
