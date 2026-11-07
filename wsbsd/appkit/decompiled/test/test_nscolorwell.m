/* test_nscolorwell.m — NSColorWell: color, active/bordered flag bits. */
#import "../src/NSColorWell.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSColorWell *w = [[NSColorWell alloc] initWithFrame:CGRectMake(0, 0, 44, 23)];
        CHECK(w.isBordered == YES, "bordered by default");
        CHECK(w.isActive == NO, "inactive by default");

        id col = [NSObject new];   /* NSColor stand-in (cluster is stage2) */
        w.color = col;
        CHECK(w.color == col, "color round-trips");

        [w activate:YES];
        CHECK(w.isActive, "activate sets the active bit");
        [w deactivate];
        CHECK(!w.isActive, "deactivate clears the active bit");

        w.bordered = NO;
        CHECK(!w.isBordered, "bordered cleared");
        /* active and bordered are independent bits */
        [w activate:NO];
        CHECK(w.isActive && !w.isBordered, "active and bordered are independent");

        CHECK([w isKindOfClass:[NSControl class]], "NSColorWell is an NSControl");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
