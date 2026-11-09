/* test_nspopover.m — NSPopover: behavior, animates/shown flags, contentSize. */
#import "../src/NSPopover.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSPopover *p = [[NSPopover alloc] init];
        CHECK(p.behavior == NSPopoverBehaviorApplicationDefined, "default behavior app-defined");
        CHECK(p.animates == YES, "animates defaults YES");
        CHECK(p.isShown == NO, "not shown initially");

        p.behavior = NSPopoverBehaviorTransient;
        CHECK(p.behavior == NSPopoverBehaviorTransient, "behavior round-trips");

        p.animates = NO;
        CHECK(!p.animates, "animates round-trips");
        /* animates (bit0) and shown (bit4) independent */
        CHECK(p.isShown == NO, "clearing animates does not set shown");

        p.contentSize = CGSizeMake(320, 200);
        CHECK(p.contentSize.width == 320 && p.contentSize.height == 200, "contentSize round-trips");

        id vc = [NSObject new];
        p.contentViewController = vc;
        CHECK(p.contentViewController == vc, "contentViewController round-trips");

        CHECK([p isKindOfClass:[NSResponder class]], "NSPopover is an NSResponder");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
