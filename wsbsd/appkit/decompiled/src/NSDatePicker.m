/* NSDatePicker.m — 1:1 (core). Delegates to NSDatePickerCell. */
#import "NSDatePicker.h"

@implementation NSDatePicker

+ (Class)cellClass { return [NSDatePickerCell class]; }
- (NSDatePickerCell *)dpCell { return (NSDatePickerCell *)self.cell; }

- (NSDate *)dateValue { return [self.dpCell dateValue]; }
- (void)setDateValue:(NSDate *)d { [self.dpCell setDateValue:d]; }
- (NSDate *)minDate { return [self.dpCell minDate]; }
- (void)setMinDate:(NSDate *)d { [self.dpCell setMinDate:d]; }
- (NSDate *)maxDate { return [self.dpCell maxDate]; }
- (void)setMaxDate:(NSDate *)d { [self.dpCell setMaxDate:d]; }
- (NSDatePickerMode)datePickerMode { return [self.dpCell datePickerMode]; }
- (void)setDatePickerMode:(NSDatePickerMode)m { [self.dpCell setDatePickerMode:m]; }
- (NSDatePickerStyle)datePickerStyle { return [self.dpCell datePickerStyle]; }
- (void)setDatePickerStyle:(NSDatePickerStyle)s { [self.dpCell setDatePickerStyle:s]; }

@end
