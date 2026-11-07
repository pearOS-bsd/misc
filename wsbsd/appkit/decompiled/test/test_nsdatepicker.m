/* test_nsdatepicker.m — NSDatePicker over NSDatePickerCell: dates, mode/style flags. */
#import "../src/NSDatePicker.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSDatePicker *dp = [[NSDatePicker alloc] initWithFrame:CGRectMake(0, 0, 140, 24)];
        CHECK([dp.cell isKindOfClass:[NSDatePickerCell class]], "cell is NSDatePickerCell");

        NSDate *now = [NSDate date];
        NSDate *lo = [now dateByAddingTimeInterval:-86400];
        NSDate *hi = [now dateByAddingTimeInterval:86400];
        dp.dateValue = now;
        dp.minDate = lo;
        dp.maxDate = hi;
        CHECK([dp.dateValue isEqualToDate:now], "dateValue round-trips");
        CHECK([dp.minDate isEqualToDate:lo], "minDate round-trips");
        CHECK([dp.maxDate isEqualToDate:hi], "maxDate round-trips");

        /* mode: bits 19-20, validated <= 1 */
        dp.datePickerMode = NSRangeDateMode;
        CHECK(dp.datePickerMode == NSRangeDateMode, "datePickerMode round-trips");
        dp.datePickerMode = (NSDatePickerMode)5;   /* out of range -> ignored */
        CHECK(dp.datePickerMode == NSRangeDateMode, "invalid mode rejected");

        /* style: bits 16-18, independent of mode */
        dp.datePickerStyle = NSClockAndCalendarDatePickerStyle;
        CHECK(dp.datePickerStyle == NSClockAndCalendarDatePickerStyle, "datePickerStyle round-trips");
        CHECK(dp.datePickerMode == NSRangeDateMode, "style change leaves mode intact");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
