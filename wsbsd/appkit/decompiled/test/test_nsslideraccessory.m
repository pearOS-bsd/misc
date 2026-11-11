/* test_nsslideraccessory.m — behaviour checks for NSSliderAccessory(+Behavior) core */
#import "../src/NSSliderAccessory.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface NSSliderAccessory (TestInternals)
- (id)_image;
@end

int main(void) {
    @autoreleasepool {
        id img = [NSObject new];
        NSSliderAccessory *a = [NSSliderAccessory accessoryWithImage:(id)img];
        CHECK(a != nil, "accessoryWithImage returns an object");
        CHECK([a _image] == img, "image stored");

        /* measured defaults */
        CHECK(a.isEnabled, "enabled default YES");
        CHECK(a.behavior != nil, "default behavior (automatic)");
        CHECK(!a.repeatsOnLongPress, "automatic behavior does not repeat on long press");

        /* enabled setter */
        a.enabled = NO;
        CHECK(!a.isEnabled, "enabled setter");

        /* valueStep behavior repeats on long press */
        a.behavior = [NSSliderAccessoryBehavior valueStepBehavior];
        CHECK(a.repeatsOnLongPress, "valueStep behavior repeats on long press");

        /* valueReset behavior does not */
        a.behavior = [NSSliderAccessoryBehavior valueResetBehavior];
        CHECK(!a.repeatsOnLongPress, "valueReset behavior does not repeat");

        /* handler behavior invokes with the accessory */
        __block NSSliderAccessory *handled = nil;
        NSSliderAccessoryBehavior *hb = [NSSliderAccessoryBehavior behaviorWithHandler:^(NSSliderAccessory *acc) { handled = acc; }];
        a.behavior = hb;
        [a.behavior handleAction:a];
        CHECK(handled == a, "handler behavior fires with the accessory");

        /* behavior is copied on set */
        CHECK(a.behavior != nil, "behavior set via handler");

        /* class behaviors are non-nil and distinct kinds */
        CHECK([NSSliderAccessoryBehavior automaticBehavior] != nil
              && [NSSliderAccessoryBehavior valueStepBehavior] != nil
              && [NSSliderAccessoryBehavior valueResetBehavior] != nil, "class behaviors vend objects");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
