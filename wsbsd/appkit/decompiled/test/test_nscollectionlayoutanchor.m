/* test_nscollectionlayoutanchor.m */
#import "../src/NSCollectionLayoutAnchor.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* edge values */
        CHECK(NSDirectionalRectEdgeTop == 1 && NSDirectionalRectEdgeLeading == 2
              && NSDirectionalRectEdgeBottom == 4 && NSDirectionalRectEdgeTrailing == 8, "edge option bits");

        /* edges-only: absolute zero offset (measured) */
        NSCollectionLayoutAnchor *a = [NSCollectionLayoutAnchor layoutAnchorWithEdges:NSDirectionalRectEdgeTop | NSDirectionalRectEdgeLeading];
        CHECK(a.edges == 3, "combined edges stored");
        CHECK(a.offset.x == 0 && a.offset.y == 0, "offset zero default");
        CHECK(a.isAbsoluteOffset && !a.isFractionalOffset, "default is absolute offset");

        /* absolute offset */
        NSCollectionLayoutAnchor *a2 = [NSCollectionLayoutAnchor layoutAnchorWithEdges:NSDirectionalRectEdgeBottom absoluteOffset:CGPointMake(5,10)];
        CHECK(a2.edges == 4 && a2.offset.x == 5 && a2.offset.y == 10, "absolute offset stored");
        CHECK(a2.isAbsoluteOffset, "absolute kind");

        /* fractional offset */
        NSCollectionLayoutAnchor *a3 = [NSCollectionLayoutAnchor layoutAnchorWithEdges:NSDirectionalRectEdgeTrailing fractionalOffset:CGPointMake(0.5,0.5)];
        CHECK(a3.isFractionalOffset && !a3.isAbsoluteOffset, "fractional kind");
        CHECK(a3.offset.x == 0.5, "fractional offset stored");

        /* NSCopying preserves kind */
        NSCollectionLayoutAnchor *c = [a3 copy];
        CHECK(c.isFractionalOffset && c.offset.x == 0.5 && c.edges == 8, "copy preserves anchor");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
