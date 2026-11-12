/* test_nscollectionlayoutsize.m */
#import "../src/NSCollectionLayoutSize.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSCollectionLayoutDimension *w = [NSCollectionLayoutDimension fractionalWidthDimension:1.0];
        NSCollectionLayoutDimension *h = [NSCollectionLayoutDimension absoluteDimension:44];
        NSCollectionLayoutSize *s = [NSCollectionLayoutSize sizeWithWidthDimension:w heightDimension:h];

        CHECK(s.widthDimension == w, "widthDimension same object (measured)");
        CHECK(s.heightDimension == h, "heightDimension same object (measured)");
        CHECK(s.widthDimension.isFractionalWidth, "width kind preserved");
        CHECK(s.heightDimension.isAbsolute && s.heightDimension.dimension == 44, "height kind + value");

        NSCollectionLayoutSize *c = [s copy];
        CHECK(c.widthDimension.dimension == 1.0 && c.heightDimension.dimension == 44, "copy preserves dimensions");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
