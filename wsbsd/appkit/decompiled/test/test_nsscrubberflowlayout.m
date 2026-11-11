/* test_nsscrubberflowlayout.m — behaviour checks for NSScrubberFlowLayout geometry */
#import "../src/NSScrubberFlowLayout.h"
#import <math.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)
#define EQ(a,b) (fabs((a)-(b)) < 1e-6)

int main(void) {
    @autoreleasepool {
        NSScrubberFlowLayout *l = [[NSScrubberFlowLayout alloc] init];
        CHECK([l isKindOfClass:[NSScrubberLayout class]], "is an NSScrubberLayout");

        /* measured defaults */
        CHECK(EQ(l.itemSpacing, 0), "itemSpacing default 0");
        CHECK(EQ(l.itemSize.width, 50) && EQ(l.itemSize.height, 30), "itemSize default 50x30");
        CHECK([NSScrubberFlowLayout layoutAttributesClass] == [NSScrubberLayoutAttributes class], "inherits layoutAttributesClass");

        /* horizontal-flow geometry */
        l.itemSize = NSMakeSize(60, 24);
        l.itemSpacing = 10;
        NSScrubberLayoutAttributes *a0 = [l layoutAttributesForItemAtIndex:0];
        NSScrubberLayoutAttributes *a1 = [l layoutAttributesForItemAtIndex:1];
        NSScrubberLayoutAttributes *a3 = [l layoutAttributesForItemAtIndex:3];
        CHECK(a0.itemIndex == 0 && EQ(a0.frame.origin.x, 0) && EQ(a0.frame.size.width, 60) && EQ(a0.frame.size.height, 24), "item 0 at x=0");
        CHECK(EQ(a1.frame.origin.x, 70), "item 1 at x = itemWidth+spacing = 70");
        CHECK(EQ(a3.frame.origin.x, 3 * 70), "item 3 at x = 3*(60+10)");
        CHECK([l layoutAttributesForItemAtIndex:-1] == nil, "negative index -> nil");

        /* no scrubber installed: content size zero, rect query empty (stage2) */
        CHECK(NSEqualSizes(l.scrubberContentSize, NSZeroSize), "content size zero without scrubber");
        CHECK([l layoutAttributesForItemsInRect:NSMakeRect(0,0,500,30)].count == 0, "rect query empty without scrubber");

        /* setters invalidate (no crash) */
        [l invalidateLayoutForItemsAtIndexes:[NSIndexSet indexSetWithIndex:0]];
        CHECK(1, "invalidateLayoutForItemsAtIndexes safe");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
