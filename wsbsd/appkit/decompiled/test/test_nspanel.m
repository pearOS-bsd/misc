/* test_nspanel.m — NSPanel (: NSWindow) flag properties. */
#import "../src/NSPanel.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSPanel *p = [[NSPanel alloc] initWithContentRect:CGRectMake(0,0,200,150)
                                                styleMask:NSWindowStyleMaskTitled
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
        CHECK([p isKindOfClass:[NSWindow class]], "NSPanel is an NSWindow");
        /* inherits NSWindow behaviour */
        p.title = @"Inspector";
        CHECK([p.title isEqualToString:@"Inspector"], "inherits NSWindow title");

        CHECK(p.isFloatingPanel == NO, "not floating by default");
        p.floatingPanel = YES;
        CHECK(p.isFloatingPanel == YES, "floatingPanel round-trips");

        p.becomesKeyOnlyIfNeeded = YES;
        CHECK(p.becomesKeyOnlyIfNeeded == YES, "becomesKeyOnlyIfNeeded round-trips");
        p.worksWhenModal = YES;
        CHECK(p.worksWhenModal == YES, "worksWhenModal round-trips");

        /* the three flags are independent bits */
        CHECK(p.isFloatingPanel && p.becomesKeyOnlyIfNeeded && p.worksWhenModal,
              "panel flags are independent");
        p.floatingPanel = NO;
        CHECK(!p.isFloatingPanel && p.becomesKeyOnlyIfNeeded && p.worksWhenModal,
              "clearing floating leaves the others");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
