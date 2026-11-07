/*
 * NSDatePickerCell.m — 1:1 (core). Evidence ../evidence/date:
 * minDate 0x18561a284 ([self+0x2c4]), datePickerMode 0x185619f78 (_dpFlags bits
 * 19-20), datePickerStyle 0x185168c88 (_dpFlags bits 16-18), setDatePickerMode:
 * 0x185619f90 (raises/ignores when > 1).
 */
#import "NSDatePickerCell.h"

@implementation NSDatePickerCell {
    NSDate *_dateValue;    /* shipping: NSCell contents (stage2) */
    NSDate *_minDate;      /* 0x2c4 */
    NSDate *_maxDate;
    uint32_t _dpFlags;     /* 0x2cc */
}

- (NSDate *)dateValue { return _dateValue; }
- (void)setDateValue:(NSDate *)dateValue { _dateValue = [dateValue copy]; }

- (NSDate *)minDate { return _minDate; }
- (void)setMinDate:(NSDate *)minDate { _minDate = [minDate copy]; }
- (NSDate *)maxDate { return _maxDate; }
- (void)setMaxDate:(NSDate *)maxDate { _maxDate = [maxDate copy]; }

- (NSDatePickerMode)datePickerMode { return (NSDatePickerMode)((_dpFlags >> 19) & 0x3u); }
- (void)setDatePickerMode:(NSDatePickerMode)datePickerMode
{
    if (datePickerMode > 1) return;   /* binary: cmp #1, b.hi -> reject */
    _dpFlags = (_dpFlags & ~(0x3u << 19)) | (((uint32_t)datePickerMode & 0x3u) << 19);
}

- (NSDatePickerStyle)datePickerStyle { return (NSDatePickerStyle)((_dpFlags >> 16) & 0x7u); }
- (void)setDatePickerStyle:(NSDatePickerStyle)datePickerStyle
{
    _dpFlags = (_dpFlags & ~(0x7u << 16)) | (((uint32_t)datePickerStyle & 0x7u) << 16);
}

@end
