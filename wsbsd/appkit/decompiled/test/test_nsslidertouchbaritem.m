/* test_nsslidertouchbaritem.m */
#import "../src/NSSliderTouchBarItem.h"
#import "../src/NSSlider.h"
#import "../src/NSSliderAccessory.h"
#import <math.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)
#define EQ(a,b) (fabs((a)-(b)) < 1e-9)

int main(void) {
    @autoreleasepool {
        NSSliderTouchBarItem *s = [[NSSliderTouchBarItem alloc] initWithIdentifier:@"id"];
        CHECK([s isKindOfClass:[NSTouchBarItem class]], "is NSTouchBarItem");
        CHECK(s.slider != nil, "slider auto-created");

        /* measured defaults */
        CHECK(EQ(s.doubleValue, 0), "doubleValue default 0");
        CHECK(EQ(s.minimumValue, 0) && EQ(s.maximumValue, 1), "slider range 0..1");
        CHECK(EQ(s.minimumSliderWidth, 64), "minimumSliderWidth 64");
        CHECK(s.maximumSliderWidth == CGFLOAT_MAX, "maximumSliderWidth CGFLOAT_MAX");
        CHECK(EQ(s.valueAccessoryWidth, 36), "valueAccessoryWidth 36");
        CHECK(s.label == nil, "label nil default");

        /* value clamps to [min,max] (measured 5 -> 1) */
        s.doubleValue = 5; CHECK(EQ(s.doubleValue, 1), "doubleValue clamps to max");
        s.doubleValue = -3; CHECK(EQ(s.doubleValue, 0), "doubleValue clamps to min");
        s.value = 0.5; CHECK(EQ(s.value, 0.5) && EQ(s.doubleValue, 0.5), "value == doubleValue");

        /* widening the range lets larger values through */
        s.maximumValue = 10;
        s.doubleValue = 7; CHECK(EQ(s.doubleValue, 7), "value in widened range");
        /* shrinking max re-clamps current value */
        s.maximumValue = 3; CHECK(EQ(s.doubleValue, 3), "shrinking max re-clamps value");
        s.minimumValue = 2; CHECK(EQ(s.minimumValue, 2), "minimumValue set");

        /* increment syncs to slider */
        s.incrementValue = 0.25;
        CHECK(EQ(s.incrementValue, 0.25), "incrementValue stored");

        /* label / widths / accessories / target-action */
        s.label = @"Vol";
        CHECK([s.label isEqual:@"Vol"], "label set");
        NSSliderAccessory *acc = [NSSliderAccessory accessoryWithImage:(id)[NSObject new]];
        s.minimumValueAccessory = acc;
        CHECK(s.minimumValueAccessory == acc, "minimumValueAccessory set");
        id tgt = [NSObject new];
        s.target = tgt; s.action = @selector(copy);
        CHECK(s.target == tgt && s.action == @selector(copy), "target/action set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
