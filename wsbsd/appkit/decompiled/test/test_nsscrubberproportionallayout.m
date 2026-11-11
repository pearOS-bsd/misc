/* test_nsscrubberproportionallayout.m — behaviour checks for NSScrubberProportionalLayout */
#import "../src/NSScrubberProportionalLayout.h"
#import "../src/NSScrubber.h"
#import <math.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)
#define EQ(a,b) (fabs((a)-(b)) < 1e-6)

@interface NSScrubberLayout (TestInternals)
- (void)_setScrubber:(id)s;
@end

int main(void) {
    @autoreleasepool {
        NSScrubberProportionalLayout *l = [[NSScrubberProportionalLayout alloc] init];
        CHECK([l isKindOfClass:[NSScrubberLayout class]], "is an NSScrubberLayout");

        /* measured defaults */
        CHECK(l.numberOfVisibleItems == 5, "numberOfVisibleItems default 5");
        CHECK([l shouldInvalidateLayoutForChangeFromVisibleRect:NSZeroRect toVisibleRect:NSMakeRect(0,0,100,30)],
              "proportional invalidates on visible-rect change");

        /* initWithNumberOfVisibleItems + setter clamp */
        NSScrubberProportionalLayout *l4 = [[NSScrubberProportionalLayout alloc] initWithNumberOfVisibleItems:4];
        CHECK(l4.numberOfVisibleItems == 4, "initWithNumberOfVisibleItems:4");
        l4.numberOfVisibleItems = 0;
        CHECK(l4.numberOfVisibleItems == 1, "numberOfVisibleItems clamps to >= 1");

        /* itemWidth 0 without an installed scrubber */
        CHECK(EQ(l.itemWidth, 0), "itemWidth 0 without scrubber");

        /* with a scrubber installed, itemWidth = width / visibleItems */
        NSScrubber *s = [[NSScrubber alloc] initWithFrame:NSMakeRect(0,0,200,30)];
        [l _setScrubber:s];
        CHECK(EQ(l.itemWidth, 40), "itemWidth = 200/5 = 40");
        NSScrubberLayoutAttributes *a0 = [l layoutAttributesForItemAtIndex:0];
        NSScrubberLayoutAttributes *a2 = [l layoutAttributesForItemAtIndex:2];
        CHECK(EQ(a0.frame.size.width, 40) && EQ(a0.frame.size.height, 30), "item size = itemWidth x scrubber height");
        CHECK(EQ(a2.frame.origin.x, 80), "item 2 at x = 2*40");

        /* numberOfVisibleItems change re-derives itemWidth */
        l.numberOfVisibleItems = 4;
        CHECK(EQ(l.itemWidth, 50), "itemWidth = 200/4 = 50 after change");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
