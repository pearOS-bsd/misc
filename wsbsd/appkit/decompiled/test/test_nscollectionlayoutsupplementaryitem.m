/* test_nscollectionlayoutsupplementaryitem.m */
#import "../src/NSCollectionLayoutSupplementaryItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSCollectionLayoutSize *sz = [NSCollectionLayoutSize
            sizeWithWidthDimension:[NSCollectionLayoutDimension absoluteDimension:20]
                   heightDimension:[NSCollectionLayoutDimension absoluteDimension:20]];
        NSCollectionLayoutAnchor *anc = [NSCollectionLayoutAnchor layoutAnchorWithEdges:NSDirectionalRectEdgeTop | NSDirectionalRectEdgeTrailing];

        NSCollectionLayoutSupplementaryItem *si = [NSCollectionLayoutSupplementaryItem
            supplementaryItemWithLayoutSize:sz elementKind:@"badge" containerAnchor:anc];

        CHECK([si isKindOfClass:[NSCollectionLayoutItem class]], "supplementary is-a NSCollectionLayoutItem");
        CHECK([si.elementKind isEqual:@"badge"], "elementKind stored");
        CHECK(si.containerAnchor == anc, "containerAnchor stored");
        CHECK(si.itemAnchor == nil, "itemAnchor nil without arg");
        CHECK(si.zIndex == 1, "zIndex default 1 (measured)");
        CHECK(si.layoutSize.widthDimension.dimension == 20, "layoutSize carried");

        /* zIndex settable */
        si.zIndex = 5; CHECK(si.zIndex == 5, "zIndex set");

        /* item anchor variant */
        NSCollectionLayoutAnchor *ia = [NSCollectionLayoutAnchor layoutAnchorWithEdges:NSDirectionalRectEdgeBottom];
        NSCollectionLayoutSupplementaryItem *si2 = [NSCollectionLayoutSupplementaryItem
            supplementaryItemWithLayoutSize:sz elementKind:@"footer" containerAnchor:anc itemAnchor:ia];
        CHECK(si2.itemAnchor == ia, "itemAnchor stored");

        /* NSCopying */
        NSCollectionLayoutSupplementaryItem *c = [si copy];
        CHECK([c.elementKind isEqual:@"badge"] && c.zIndex == 5 && c.containerAnchor == anc, "copy preserves state");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
