/* NSDatePicker.h — 1:1 (core). NSControl backed by NSDatePickerCell; delegates.
 * Evidence ../evidence/date (minDate 0x185616a4c -> cell). */
#import "NSControl.h"
#import "NSDatePickerCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSDatePicker : NSControl
@property (nullable, copy) NSDate *dateValue;
@property (nullable, copy) NSDate *minDate;
@property (nullable, copy) NSDate *maxDate;
@property NSDatePickerMode datePickerMode;
@property NSDatePickerStyle datePickerStyle;
@end

NS_ASSUME_NONNULL_END
