/* test_nscollectionlayoutedgespacing.m */
#import "../src/NSCollectionLayoutEdgeSpacing.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSCollectionLayoutSpacing *lead = [NSCollectionLayoutSpacing fixedSpacing:2];
        NSCollectionLayoutSpacing *trail = [NSCollectionLayoutSpacing flexibleSpacing:3];
        NSCollectionLayoutEdgeSpacing *e = [NSCollectionLayoutEdgeSpacing spacingForLeading:lead top:nil trailing:trail bottom:nil];

        CHECK(e.leading == lead, "leading stored");
        CHECK(e.top == nil, "top nil");
        CHECK(e.trailing == trail, "trailing stored");
        CHECK(e.bottom == nil, "bottom nil");
        CHECK(e.leading.isFixedSpacing && e.leading.spacing == 2, "leading kind + value");
        CHECK(e.trailing.isFlexibleSpacing && e.trailing.spacing == 3, "trailing kind + value");

        NSCollectionLayoutEdgeSpacing *c = [e copy];
        CHECK(c.leading.spacing == 2 && c.trailing.spacing == 3 && c.top == nil, "copy preserves edges");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
