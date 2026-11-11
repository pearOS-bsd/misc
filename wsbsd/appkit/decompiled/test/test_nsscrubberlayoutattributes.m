/* test_nsscrubberlayoutattributes.m — behaviour checks for NSScrubberLayoutAttributes */
#import "../src/NSScrubberLayoutAttributes.h"
#import <math.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* measured defaults */
        NSScrubberLayoutAttributes *a = [[NSScrubberLayoutAttributes alloc] init];
        CHECK(a.itemIndex == -1, "itemIndex default -1");
        CHECK(a.alpha == 1.0, "alpha default 1.0");
        CHECK(NSEqualRects(a.frame, NSZeroRect), "frame default zero");
        CHECK(!a.escapesFromScrollView, "escapesFromScrollView default NO");

        /* factory sets index, alpha stays 1 */
        NSScrubberLayoutAttributes *b = [NSScrubberLayoutAttributes layoutAttributesForItemAtIndex:5];
        CHECK(b.itemIndex == 5 && b.alpha == 1.0, "factory sets index, default alpha");

        /* setters */
        b.frame = NSMakeRect(10, 0, 40, 30);
        b.alpha = 0.5;
        b.escapesFromScrollView = YES;
        CHECK(b.frame.size.width == 40 && b.alpha == 0.5 && b.escapesFromScrollView, "setters");

        /* isEqual compares itemIndex + frame + alpha */
        NSScrubberLayoutAttributes *c = [NSScrubberLayoutAttributes layoutAttributesForItemAtIndex:5];
        c.frame = NSMakeRect(10, 0, 40, 30);
        c.alpha = 0.5;
        CHECK([b isEqual:c], "equal when index/frame/alpha match");
        c.alpha = 0.9;
        CHECK(![b isEqual:c], "unequal when alpha differs");
        c.alpha = 0.5; c.itemIndex = 6;
        CHECK(![b isEqual:c], "unequal when index differs");

        /* copy carries all fields */
        NSScrubberLayoutAttributes *cp = [b copy];
        CHECK(cp.itemIndex == 5 && cp.frame.size.width == 40 && cp.alpha == 0.5 && cp.escapesFromScrollView,
              "copy carries all fields");
        CHECK([cp isEqual:b], "copy equals original");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
