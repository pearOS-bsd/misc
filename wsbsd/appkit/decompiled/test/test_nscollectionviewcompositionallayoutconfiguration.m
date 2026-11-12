/* test_nscollectionviewcompositionallayoutconfiguration.m */
#import "../src/NSCollectionViewCompositionalLayoutConfiguration.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSCollectionViewCompositionalLayoutConfiguration *cfg = [[NSCollectionViewCompositionalLayoutConfiguration alloc] init];

        /* measured defaults */
        CHECK(cfg.scrollDirection == NSCollectionViewScrollDirectionVertical, "scrollDirection Vertical default");
        CHECK(cfg.interSectionSpacing == 0, "interSectionSpacing 0 default");
        CHECK(cfg.boundarySupplementaryItems.count == 0, "no boundary items default");

        /* setters */
        cfg.scrollDirection = NSCollectionViewScrollDirectionHorizontal;
        CHECK(cfg.scrollDirection == NSCollectionViewScrollDirectionHorizontal, "scrollDirection set");
        cfg.interSectionSpacing = 20;
        CHECK(cfg.interSectionSpacing == 20, "interSectionSpacing set");
        cfg.boundarySupplementaryItems = @[[NSObject new]];
        CHECK(cfg.boundarySupplementaryItems.count == 1, "boundary items set");

        /* NSCopying */
        NSCollectionViewCompositionalLayoutConfiguration *c = [cfg copy];
        CHECK(c.scrollDirection == NSCollectionViewScrollDirectionHorizontal
              && c.interSectionSpacing == 20 && c.boundarySupplementaryItems.count == 1, "copy preserves config");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
