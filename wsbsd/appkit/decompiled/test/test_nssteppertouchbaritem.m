/* test_nssteppertouchbaritem.m */
#import "../src/NSStepperTouchBarItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSFormatter *fmt = [[NSNumberFormatter alloc] init];
        NSStepperTouchBarItem *s = [NSStepperTouchBarItem stepperTouchBarItemWithIdentifier:@"id" formatter:fmt];
        CHECK([s isKindOfClass:[NSTouchBarItem class]], "is NSTouchBarItem");
        CHECK([s.identifier isEqual:@"id"], "identifier set");
        CHECK(s.formatter == fmt, "formatter from factory");

        /* measured defaults */
        CHECK(s.minValue == 0 && s.maxValue == 59 && s.increment == 1 && s.value == 0, "numeric defaults 0/59/1/0");

        /* value clamps to [min,max] */
        s.value = 100; CHECK(s.value == 59, "value clamps to max");
        s.value = -5;  CHECK(s.value == 0, "value clamps to min");
        s.value = 30;  CHECK(s.value == 30, "value in range");

        /* lowering max pulls value down */
        s.maxValue = 20; CHECK(s.value == 20, "lowering max clamps value");
        /* raising min pulls value up */
        s.minValue = 25; CHECK(s.value == 25, "raising min clamps value");

        /* increment + target/action + customizationLabel */
        s.increment = 5; CHECK(s.increment == 5, "increment set");
        id tgt = [NSObject new];
        s.target = tgt; s.action = @selector(copy);
        CHECK(s.target == tgt && s.action == @selector(copy), "target/action set");
        s.customizationLabel = @"Step";
        CHECK([s.customizationLabel isEqual:@"Step"], "customizationLabel set");

        /* drawingHandler factory */
        NSStepperTouchBarItem *s2 = [NSStepperTouchBarItem stepperTouchBarItemWithIdentifier:@"id2" drawingHandler:^(id r, double v){ (void)r; (void)v; }];
        CHECK(s2 != nil && s2.formatter == nil, "drawingHandler factory (no formatter)");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
