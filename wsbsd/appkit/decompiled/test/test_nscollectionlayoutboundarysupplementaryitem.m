/* test_nscollectionlayoutboundarysupplementaryitem.m */
#import "../src/NSCollectionLayoutBoundarySupplementaryItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSCollectionLayoutSize *sz = [NSCollectionLayoutSize
            sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
                   heightDimension:[NSCollectionLayoutDimension absoluteDimension:30]];

        NSCollectionLayoutBoundarySupplementaryItem *b = [NSCollectionLayoutBoundarySupplementaryItem
            boundarySupplementaryItemWithLayoutSize:sz elementKind:@"header" alignment:NSRectAlignmentTop];

        CHECK([b isKindOfClass:[NSCollectionLayoutSupplementaryItem class]], "boundary is-a supplementary item");
        CHECK([b.elementKind isEqual:@"header"], "elementKind stored");
        CHECK(b.alignment == NSRectAlignmentTop, "alignment stored");
        CHECK(b.offset.x == 0 && b.offset.y == 0, "offset zero default");
        CHECK(b.extendsBoundary, "extendsBoundary YES default");
        CHECK(!b.pinToVisibleBounds, "pinToVisibleBounds NO default");
        CHECK(b.zIndex == 1, "zIndex 1 default");
        CHECK(b.layoutSize.heightDimension.dimension == 30, "layoutSize carried");

        /* enum */
        CHECK(NSRectAlignmentLeading == 3 && NSRectAlignmentTrailing == 7 && NSRectAlignmentTopTrailing == 8, "NSRectAlignment enum");

        /* offset variant */
        NSCollectionLayoutBoundarySupplementaryItem *b2 = [NSCollectionLayoutBoundarySupplementaryItem
            boundarySupplementaryItemWithLayoutSize:sz elementKind:@"footer" alignment:NSRectAlignmentBottom absoluteOffset:CGPointMake(0,-4)];
        CHECK(b2.offset.y == -4 && b2.alignment == NSRectAlignmentBottom, "offset variant stored");

        /* setters */
        b.pinToVisibleBounds = YES; CHECK(b.pinToVisibleBounds, "pinToVisibleBounds set");
        b.extendsBoundary = NO; CHECK(!b.extendsBoundary, "extendsBoundary set");

        /* NSCopying */
        NSCollectionLayoutBoundarySupplementaryItem *c = [b copy];
        CHECK([c.elementKind isEqual:@"header"] && c.pinToVisibleBounds && !c.extendsBoundary && c.alignment == NSRectAlignmentTop, "copy preserves state");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
