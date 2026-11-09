/* test_nsswitch.m — NSSwitch toggle + action. */
#import "../src/NSSwitch.h"
#import "../src/NSControl.h"
#import "../src/NSApplication.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

@interface Obs : NSObject
@property int hits;
@end
@implementation Obs
- (void)flip:(id)sender { _hits++; }
@end

int main(void)
{
    @autoreleasepool {
        [NSApplication sharedApplication];   /* NSControl action dispatch routes through NSApp */
        NSSwitch *sw = [[NSSwitch alloc] initWithFrame:CGRectMake(0,0,40,20)];
        CHECK([sw isKindOfClass:[NSControl class]], "NSSwitch is an NSControl");
        CHECK(sw.state == NSControlStateValueOff, "off by default");

        sw.state = NSControlStateValueOn;
        CHECK(sw.state == NSControlStateValueOn, "state on set");
        sw.state = 42;
        CHECK(sw.state == NSControlStateValueOn, "any non-zero normalizes to On");
        sw.state = NSControlStateValueOff;
        CHECK(sw.state == NSControlStateValueOff, "state off set");

        /* performClick toggles and fires the action */
        Obs *obs = [Obs new];
        sw.target = obs;
        sw.action = @selector(flip:);
        [sw performClick:nil];
        CHECK(sw.state == NSControlStateValueOn, "performClick toggles off->on");
        CHECK(obs.hits == 1, "performClick fires the action");
        [sw performClick:nil];
        CHECK(sw.state == NSControlStateValueOff, "performClick toggles on->off");
        CHECK(obs.hits == 2, "performClick fires again");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
