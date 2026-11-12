/* test_nscollectionlayoutitem.m */
#import "../src/NSCollectionLayoutItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSCollectionLayoutSize *sz = [NSCollectionLayoutSize
            sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
                   heightDimension:[NSCollectionLayoutDimension absoluteDimension:44]];

        NSCollectionLayoutItem *it = [NSCollectionLayoutItem itemWithLayoutSize:sz];
        /* measured: size is copied, dimensions preserved */
        CHECK(it.layoutSize != nil, "layoutSize present");
        CHECK(it.layoutSize.widthDimension.isFractionalWidth && it.layoutSize.heightDimension.dimension == 44, "layoutSize dimensions preserved");

        /* measured defaults */
        NSDirectionalEdgeInsets ci = it.contentInsets;
        CHECK(ci.top == 0 && ci.leading == 0 && ci.bottom == 0 && ci.trailing == 0, "contentInsets zero default");
        CHECK(it.supplementaryItems.count == 0, "no supplementary items default");

        /* setters */
        it.contentInsets = NSDirectionalEdgeInsetsMake(1,2,3,4);
        CHECK(it.contentInsets.top == 1 && it.contentInsets.leading == 2
              && it.contentInsets.bottom == 3 && it.contentInsets.trailing == 4, "contentInsets set");
        NSCollectionLayoutEdgeSpacing *es = [NSCollectionLayoutEdgeSpacing
            spacingForLeading:[NSCollectionLayoutSpacing fixedSpacing:2] top:nil trailing:nil bottom:nil];
        it.edgeSpacing = es;
        CHECK(it.edgeSpacing.leading.spacing == 2, "edgeSpacing set");

        /* supplementary items factory */
        id supp = [NSObject new];
        NSCollectionLayoutItem *it2 = [NSCollectionLayoutItem itemWithLayoutSize:sz supplementaryItems:@[supp]];
        CHECK(it2.supplementaryItems.count == 1, "supplementary items stored");

        /* NSCopying */
        NSCollectionLayoutItem *c = [it copy];
        CHECK(c.contentInsets.leading == 2 && c.edgeSpacing.leading.spacing == 2, "copy preserves insets + edge spacing");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
