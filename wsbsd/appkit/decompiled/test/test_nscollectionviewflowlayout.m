/* test_nscollectionviewflowlayout.m — behaviour checks for flow-layout config core */
#import "../src/NSCollectionViewFlowLayout.h"
#import <math.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)
#define EQ(a,b) (fabs((a)-(b)) < 1e-9)

@interface NSCollectionViewLayout (TestInternals)
- (void)_setPrepared:(BOOL)p;
- (BOOL)_isPrepared;
@end

int main(void) {
    @autoreleasepool {
        NSCollectionViewFlowLayout *fl = [[NSCollectionViewFlowLayout alloc] init];
        CHECK([fl isKindOfClass:[NSCollectionViewLayout class]], "is an NSCollectionViewLayout");

        /* documented defaults */
        CHECK(EQ(fl.minimumLineSpacing, 10.0), "default lineSpacing 10");
        CHECK(EQ(fl.minimumInteritemSpacing, 10.0), "default interitemSpacing 10");
        CHECK(EQ(fl.itemSize.width, 50.0) && EQ(fl.itemSize.height, 50.0), "default itemSize 50x50");
        CHECK(NSEqualSizes(fl.estimatedItemSize, NSZeroSize), "default estimatedItemSize zero");
        CHECK(fl.scrollDirection == NSCollectionViewScrollDirectionVertical, "default vertical");
        CHECK(NSEqualSizes(fl.headerReferenceSize, NSZeroSize), "default header size zero");
        CHECK(NSEqualSizes(fl.footerReferenceSize, NSZeroSize), "default footer size zero");
        CHECK(fl.sectionInset.top == 0 && fl.sectionInset.left == 0, "default sectionInset zero");
        CHECK(!fl.sectionHeadersPinToVisibleBounds && !fl.sectionFootersPinToVisibleBounds, "default pins NO");

        /* setters update + invalidate */
        [fl _setPrepared:YES];
        fl.minimumLineSpacing = 4.0;
        CHECK(EQ(fl.minimumLineSpacing, 4.0) && ![fl _isPrepared], "set lineSpacing invalidates");

        [fl _setPrepared:YES];
        fl.itemSize = NSMakeSize(80, 120);
        CHECK(EQ(fl.itemSize.width, 80) && ![fl _isPrepared], "set itemSize invalidates");

        [fl _setPrepared:YES];
        fl.scrollDirection = NSCollectionViewScrollDirectionHorizontal;
        CHECK(fl.scrollDirection == NSCollectionViewScrollDirectionHorizontal && ![fl _isPrepared], "set scrollDirection invalidates");

        [fl _setPrepared:YES];
        fl.sectionInset = NSEdgeInsetsMake(5, 6, 7, 8);
        CHECK(fl.sectionInset.left == 6 && fl.sectionInset.right == 8 && ![fl _isPrepared], "set sectionInset invalidates");

        /* setting the same value does not invalidate */
        [fl _setPrepared:YES];
        fl.minimumLineSpacing = 4.0;
        CHECK([fl _isPrepared], "setting identical value does not invalidate");

        [fl _setPrepared:YES];
        fl.sectionHeadersPinToVisibleBounds = YES;
        CHECK(fl.sectionHeadersPinToVisibleBounds && ![fl _isPrepared], "set header pin invalidates");

        /* collapse / expand */
        CHECK(![fl sectionAtIndexIsCollapsed:2], "section not collapsed initially");
        [fl _setPrepared:YES];
        [fl collapseSectionAtIndex:2];
        CHECK([fl sectionAtIndexIsCollapsed:2] && ![fl _isPrepared], "collapse records + invalidates");
        [fl _setPrepared:YES];
        [fl collapseSectionAtIndex:2];
        CHECK([fl _isPrepared], "re-collapsing same section is a no-op");
        [fl _setPrepared:YES];
        [fl expandSectionAtIndex:2];
        CHECK(![fl sectionAtIndexIsCollapsed:2] && ![fl _isPrepared], "expand clears + invalidates");
        [fl _setPrepared:YES];
        [fl expandSectionAtIndex:2];
        CHECK([fl _isPrepared], "expanding non-collapsed is a no-op");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
