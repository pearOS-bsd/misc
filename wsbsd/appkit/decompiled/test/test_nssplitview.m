/* test_nssplitview.m — NSSplitView: isVertical flag bit, dividerStyle/thickness. */
#import "../src/NSSplitView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSSplitView *sp = [[NSSplitView alloc] initWithFrame:CGRectMake(0, 0, 300, 200)];
        CHECK(sp.isVertical == NO, "horizontal by default");
        sp.vertical = YES;
        CHECK(sp.isVertical == YES, "isVertical round-trips");
        sp.vertical = NO;
        CHECK(sp.isVertical == NO, "isVertical cleared");

        CHECK(sp.dividerStyle == NSSplitViewDividerStyleThin, "default divider style thin");
        CHECK(sp.dividerThickness == 1.0, "thin divider is 1pt");
        sp.dividerStyle = NSSplitViewDividerStyleThick;
        CHECK(sp.dividerStyle == NSSplitViewDividerStyleThick, "dividerStyle round-trips");
        CHECK(sp.dividerThickness == 10.0, "thick divider is thicker");

        /* vertical and style are independent */
        sp.vertical = YES;
        CHECK(sp.isVertical && sp.dividerStyle == NSSplitViewDividerStyleThick,
              "vertical and style independent");

        CHECK([sp isKindOfClass:[NSView class]], "NSSplitView is an NSView");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
