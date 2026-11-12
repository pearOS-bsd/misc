/* test_nscollectionlayoutspacing.m */
#import "../src/NSCollectionLayoutSpacing.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSCollectionLayoutSpacing *fx = [NSCollectionLayoutSpacing fixedSpacing:10];
        CHECK(fx.spacing == 10, "fixed spacing value");
        CHECK(fx.isFixedSpacing && !fx.isFlexibleSpacing, "fixed kind exclusive");

        NSCollectionLayoutSpacing *fl = [NSCollectionLayoutSpacing flexibleSpacing:5];
        CHECK(fl.spacing == 5, "flexible spacing value");
        CHECK(fl.isFlexibleSpacing && !fl.isFixedSpacing, "flexible kind exclusive");

        NSCollectionLayoutSpacing *c = [fl copy];
        CHECK(c.isFlexibleSpacing && c.spacing == 5, "copy preserves kind + value");
        NSCollectionLayoutSpacing *c2 = [fx copy];
        CHECK(c2.isFixedSpacing && c2.spacing == 10, "copy preserves fixed");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
