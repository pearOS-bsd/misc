/* test_nscollectionviewgridlayout.m — behaviour checks for grid-layout config core */
#import "../src/NSCollectionViewGridLayout.h"
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
        NSCollectionViewGridLayout *g = [[NSCollectionViewGridLayout alloc] init];
        CHECK([g isKindOfClass:[NSCollectionViewLayout class]], "is an NSCollectionViewLayout");

        /* measured defaults: all zero, empty bg */
        CHECK(g.maximumNumberOfRows == 0 && g.maximumNumberOfColumns == 0, "default rows/cols 0");
        CHECK(NSEqualSizes(g.minimumItemSize, NSZeroSize) && NSEqualSizes(g.maximumItemSize, NSZeroSize), "default item sizes zero");
        CHECK(g.margins.top == 0 && g.margins.left == 0 && g.margins.bottom == 0 && g.margins.right == 0, "default margins zero");
        CHECK(EQ(g.minimumInteritemSpacing, 0) && EQ(g.minimumLineSpacing, 0), "default spacings 0");
        CHECK(g.backgroundColors.count == 0, "default backgroundColors empty");

        /* setters update + invalidate */
        [g _setPrepared:YES];
        g.maximumNumberOfColumns = 4;
        CHECK(g.maximumNumberOfColumns == 4 && ![g _isPrepared], "set maxColumns invalidates");

        [g _setPrepared:YES];
        g.minimumItemSize = NSMakeSize(40, 40);
        CHECK(EQ(g.minimumItemSize.width, 40) && ![g _isPrepared], "set minItemSize invalidates");

        [g _setPrepared:YES];
        g.maximumItemSize = NSMakeSize(100, 100);
        CHECK(EQ(g.maximumItemSize.height, 100) && ![g _isPrepared], "set maxItemSize invalidates");

        [g _setPrepared:YES];
        g.margins = NSEdgeInsetsMake(1, 2, 3, 4);
        CHECK(g.margins.left == 2 && g.margins.right == 4 && ![g _isPrepared], "set margins invalidates");

        [g _setPrepared:YES];
        g.minimumLineSpacing = 6;
        CHECK(EQ(g.minimumLineSpacing, 6) && ![g _isPrepared], "set lineSpacing invalidates");

        /* identical value does not invalidate */
        [g _setPrepared:YES];
        g.maximumNumberOfColumns = 4;
        CHECK([g _isPrepared], "identical maxColumns no-op");

        /* backgroundColors copies */
        NSMutableArray *bg = [@[@"a", @"b"] mutableCopy];
        g.backgroundColors = bg;
        [bg addObject:@"c"];
        CHECK(g.backgroundColors.count == 2, "backgroundColors is a snapshot copy");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
