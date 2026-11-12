/* test_nscollectionlayoutsection.m */
#import "../src/NSCollectionLayoutSection.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

static NSCollectionLayoutGroup *mkGroup(void) {
    NSCollectionLayoutSize *sz = [NSCollectionLayoutSize
        sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1]
               heightDimension:[NSCollectionLayoutDimension absoluteDimension:44]];
    NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:sz];
    return [NSCollectionLayoutGroup verticalGroupWithLayoutSize:sz subitems:@[item]];
}

int main(void) {
    @autoreleasepool {
        NSCollectionLayoutSection *s = [NSCollectionLayoutSection sectionWithGroup:mkGroup()];

        /* measured defaults */
        CHECK(s.interGroupSpacing == 0, "interGroupSpacing 0 default");
        CHECK(s.orthogonalScrollingBehavior == NSCollectionLayoutSectionOrthogonalScrollingBehaviorNone, "ortho None default");
        CHECK(s.supplementariesFollowContentInsets, "supplementariesFollowContentInsets YES default");
        CHECK(s.boundarySupplementaryItems.count == 0, "no boundary items default");
        CHECK(s.decorationItems.count == 0, "no decoration items default");
        CHECK(s.contentInsets.leading == 0, "contentInsets zero default");

        /* enum */
        CHECK(NSCollectionLayoutSectionOrthogonalScrollingBehaviorPaging == 3
              && NSCollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered == 5, "ortho enum");

        /* setters */
        s.interGroupSpacing = 12; CHECK(s.interGroupSpacing == 12, "interGroupSpacing set");
        s.orthogonalScrollingBehavior = NSCollectionLayoutSectionOrthogonalScrollingBehaviorContinuous;
        CHECK(s.orthogonalScrollingBehavior == 1, "ortho set");
        s.supplementariesFollowContentInsets = NO; CHECK(!s.supplementariesFollowContentInsets, "supplementariesFollow set");
        s.contentInsets = NSDirectionalEdgeInsetsMake(5,6,7,8);
        CHECK(s.contentInsets.trailing == 8, "contentInsets set");
        s.boundarySupplementaryItems = @[[NSObject new]];
        CHECK(s.boundarySupplementaryItems.count == 1, "boundary items set");

        /* NSCopying */
        NSCollectionLayoutSection *c = [s copy];
        CHECK(c.interGroupSpacing == 12 && c.orthogonalScrollingBehavior == 1
              && !c.supplementariesFollowContentInsets && c.contentInsets.trailing == 8
              && c.boundarySupplementaryItems.count == 1, "copy preserves section state");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
