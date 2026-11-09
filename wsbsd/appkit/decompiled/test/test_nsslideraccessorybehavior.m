/* test — NSSliderAccessoryBehavior dispatch. */
#import "../src/NSSliderAccessoryBehavior.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

@interface Target : NSObject
@property int hits; @property id lastSender;
@end
@implementation Target
- (void)act:(id)sender { _hits++; _lastSender = sender; }
@end

int main(void)
{
    @autoreleasepool {
        CHECK([NSSliderAccessoryBehavior automaticBehavior] != nil, "automatic behavior builds");
        CHECK([NSSliderAccessoryBehavior valueResetBehavior] != nil, "value-reset behavior builds");
        CHECK([NSSliderAccessoryBehavior valueStepBehavior] != nil, "value-step behavior builds");

        /* built-in handleAction is a no-op (no crash) */
        [[NSSliderAccessoryBehavior automaticBehavior] handleAction:nil];
        CHECK(1, "built-in handleAction does not crash");

        /* handler */
        __block int ran = 0; __block id seen = nil;
        id sender = [NSObject new];
        NSSliderAccessoryBehavior *h = [NSSliderAccessoryBehavior behaviorWithHandler:^(id s){ ran++; seen = s; }];
        [h handleAction:sender];
        CHECK(ran == 1 && seen == sender, "handler runs with the sender");

        /* target/action */
        Target *t = [Target new];
        NSSliderAccessoryBehavior *ta = [NSSliderAccessoryBehavior behaviorWithTarget:t action:@selector(act:)];
        [ta handleAction:sender];
        CHECK(t.hits == 1 && t.lastSender == sender, "target/action invoked with the sender");

        /* copy keeps behaving */
        NSSliderAccessoryBehavior *c = [ta copy];
        [c handleAction:sender];
        CHECK(t.hits == 2, "copy still dispatches to the target");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
