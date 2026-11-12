/* test_nstableheadercell.m */
#import "../src/NSTableHeaderCell.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSTableHeaderCell *c = [[NSTableHeaderCell alloc] initTextCell:@"Name"];
        CHECK([c isKindOfClass:[NSTextFieldCell class]], "is-a NSTextFieldCell");
        CHECK([c.stringValue isEqual:@"Name"], "title stored");

        /* measured: sort-indicator geometry for {0,0,80,20} => {{63,6},{9,9}} */
        CGRect r = [c sortIndicatorRectForBounds:NSMakeRect(0,0,80,20)];
        CHECK(r.size.width == 9 && r.size.height == 9, "indicator is 9x9");
        CHECK(r.origin.x == 63, "indicator x at trailing edge (maxX-9-8)");
        CHECK(r.origin.y == 6, "indicator vertically centered");

        /* scales with bounds width + height */
        CGRect r2 = [c sortIndicatorRectForBounds:NSMakeRect(0,0,120,30)];
        CHECK(r2.origin.x == 103, "trailing edge tracks width (120-9-8)");
        CHECK(r2.origin.y == 11, "centered for height 30 (round((30-9)/2)=11)");

        /* drawing is a stage2 no-op; must not crash */
        [c drawSortIndicatorWithFrame:NSMakeRect(0,0,80,20) inView:nil ascending:YES priority:0];
        CHECK(1, "drawSortIndicator stage2 no-op safe");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
