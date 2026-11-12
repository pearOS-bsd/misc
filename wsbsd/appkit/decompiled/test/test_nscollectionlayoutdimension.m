/* test_nscollectionlayoutdimension.m */
#import "../src/NSCollectionLayoutDimension.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSCollectionLayoutDimension *fw = [NSCollectionLayoutDimension fractionalWidthDimension:0.5];
        CHECK(fw.isFractionalWidth && !fw.isFractionalHeight && !fw.isAbsolute && !fw.isEstimated, "fractionalWidth kind exclusive");
        CHECK(fw.dimension == 0.5, "fractionalWidth value");

        NSCollectionLayoutDimension *fh = [NSCollectionLayoutDimension fractionalHeightDimension:0.25];
        CHECK(fh.isFractionalHeight && !fh.isFractionalWidth, "fractionalHeight kind");
        CHECK(fh.dimension == 0.25, "fractionalHeight value");

        NSCollectionLayoutDimension *ab = [NSCollectionLayoutDimension absoluteDimension:44];
        CHECK(ab.isAbsolute && !ab.isEstimated, "absolute kind");
        CHECK(ab.dimension == 44, "absolute value");

        NSCollectionLayoutDimension *es = [NSCollectionLayoutDimension estimatedDimension:100];
        CHECK(es.isEstimated && !es.isAbsolute, "estimated kind");
        CHECK(es.dimension == 100, "estimated value");

        /* NSCopying preserves kind + value */
        NSCollectionLayoutDimension *c = [ab copy];
        CHECK(c.isAbsolute && c.dimension == 44, "copy preserves kind + value");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
