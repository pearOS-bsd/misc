/* test_nscollectionlayoutgroup.m */
#import "../src/NSCollectionLayoutGroup.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

static NSCollectionLayoutSize *mkSize(CGFloat w, CGFloat h) {
    return [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:w]
                                         heightDimension:[NSCollectionLayoutDimension absoluteDimension:h]];
}

int main(void) {
    @autoreleasepool {
        NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:mkSize(0.5, 44)];
        NSCollectionLayoutSize *gsz = mkSize(1.0, 100);

        NSCollectionLayoutGroup *h = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:gsz subitems:@[item]];
        CHECK([h isKindOfClass:[NSCollectionLayoutItem class]], "group is-a NSCollectionLayoutItem");
        CHECK(h.subitems.count == 1 && h.subitems[0] == item, "horizontal subitems stored");
        CHECK(h.layoutSize.heightDimension.dimension == 100, "group layoutSize carried");

        NSCollectionLayoutGroup *v = [NSCollectionLayoutGroup verticalGroupWithLayoutSize:gsz subitems:@[item, item]];
        CHECK(v.subitems.count == 2, "vertical subitems stored");

        /* interItemSpacing settable */
        h.interItemSpacing = [NSCollectionLayoutSpacing fixedSpacing:8];
        CHECK(h.interItemSpacing.spacing == 8 && h.interItemSpacing.isFixedSpacing, "interItemSpacing set");

        /* inherited NSCollectionLayoutItem behaviour still works */
        h.contentInsets = NSDirectionalEdgeInsetsMake(0,4,0,4);
        CHECK(h.contentInsets.leading == 4, "inherited contentInsets works");

        /* NSCopying preserves subitems + spacing + inherited insets */
        NSCollectionLayoutGroup *c = [h copy];
        CHECK(c.subitems.count == 1 && c.interItemSpacing.spacing == 8 && c.contentInsets.leading == 4, "copy preserves group state");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
