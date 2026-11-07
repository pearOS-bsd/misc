/*
 * test_nsbox.m — NSBox packed _bFlags: boxType, borderType, titlePosition,
 * transparent (independent bitfields), plus title and border/corner metrics.
 */
#import "../src/NSBox.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        NSBox *box = [[NSBox alloc] initWithFrame:CGRectMake(0, 0, 200, 120)];

        /* defaults from init */
        CHECK(box.borderType == NSBezelBorder, "default borderType bezel");
        CHECK(box.titlePosition == NSAtTop, "default titlePosition at top");
        CHECK(box.boxType == NSBoxPrimary, "default boxType primary");

        /* each field round-trips */
        box.boxType = NSBoxCustom;
        CHECK(box.boxType == NSBoxCustom, "boxType round-trips");
        box.borderType = NSGrooveBorder;
        CHECK(box.borderType == NSGrooveBorder, "borderType round-trips");
        box.titlePosition = NSBelowBottom;
        CHECK(box.titlePosition == NSBelowBottom, "titlePosition round-trips");

        /* independent bitfields: setting one leaves the others intact */
        CHECK(box.boxType == NSBoxCustom && box.borderType == NSGrooveBorder && box.titlePosition == NSBelowBottom,
              "packed fields are independent");

        box.transparent = YES;
        CHECK(box.isTransparent, "transparent set");
        CHECK(box.boxType == NSBoxCustom && box.borderType == NSGrooveBorder,
              "transparent bit does not disturb boxType/borderType");
        box.transparent = NO;
        CHECK(!box.isTransparent, "transparent cleared");

        /* title + metrics */
        box.title = @"Settings";
        CHECK([box.title isEqualToString:@"Settings"], "title round-trips");
        box.borderWidth = 2.5;
        CHECK(box.borderWidth == 2.5, "borderWidth round-trips");
        box.cornerRadius = 6.0;
        CHECK(box.cornerRadius == 6.0, "cornerRadius round-trips");

        /* it is an NSView */
        CHECK([box isKindOfClass:[NSView class]], "NSBox is an NSView");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
