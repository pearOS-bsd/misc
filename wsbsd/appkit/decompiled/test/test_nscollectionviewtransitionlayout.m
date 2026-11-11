/* test_nscollectionviewtransitionlayout.m — behaviour checks for the transition layout core */
#import "../src/NSCollectionViewTransitionLayout.h"
#import "../src/NSCollectionViewFlowLayout.h"
#import <math.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)
#define EQ(a,b) (fabs((a)-(b)) < 1e-6)

@interface NSCollectionViewLayout (TestInternals)
- (void)_setPrepared:(BOOL)p;
- (BOOL)_isPrepared;
@end

int main(void) {
    @autoreleasepool {
        NSCollectionViewFlowLayout *a = [[NSCollectionViewFlowLayout alloc] init];
        NSCollectionViewFlowLayout *b = [[NSCollectionViewFlowLayout alloc] init];
        NSCollectionViewTransitionLayout *t = [[NSCollectionViewTransitionLayout alloc] initWithCurrentLayout:a nextLayout:b];

        CHECK([t isKindOfClass:[NSCollectionViewLayout class]], "is an NSCollectionViewLayout");
        CHECK(t.currentLayout == a && t.nextLayout == b, "current/next layouts stored");
        CHECK(EQ(t.transitionProgress, 0.0), "transitionProgress default 0");

        /* progress is not clamped; setting invalidates */
        [t _setPrepared:YES];
        t.transitionProgress = 2.0;
        CHECK(EQ(t.transitionProgress, 2.0) && ![t _isPrepared], "progress unclamped + invalidates");
        t.transitionProgress = -1.0;
        CHECK(EQ(t.transitionProgress, -1.0), "progress accepts negative");
        t.transitionProgress = 0.5;

        /* animated key store/retrieve (default 0) */
        CHECK(EQ([t valueForAnimatedKey:@"k"], 0.0), "valueForAnimatedKey default 0");
        [t updateValue:0.75 forAnimatedKey:@"k"];
        CHECK(EQ([t valueForAnimatedKey:@"k"], 0.75), "animated value stored/retrieved");

        /* attribute interpolation at progress 0.5 */
        NSIndexPath *ip = [NSIndexPath indexPathWithIndex:0];
        NSCollectionViewLayoutAttributes *fa = [NSCollectionViewLayoutAttributes layoutAttributesForItemWithIndexPath:ip];
        fa.frame = NSMakeRect(0, 0, 100, 100); fa.alpha = 0.0; fa.zIndex = 1;
        NSCollectionViewLayoutAttributes *ta = [NSCollectionViewLayoutAttributes layoutAttributesForItemWithIndexPath:ip];
        ta.frame = NSMakeRect(100, 200, 200, 300); ta.alpha = 1.0; ta.zIndex = 9;
        NSCollectionViewLayoutAttributes *mid = [t interpolatedLayoutAttributesFromLayoutAttributes:fa toLayoutAttributes:ta progress:0.5];
        CHECK(EQ(mid.frame.origin.x, 50) && EQ(mid.frame.origin.y, 100), "interpolated origin midpoint");
        CHECK(EQ(mid.frame.size.width, 150) && EQ(mid.frame.size.height, 200), "interpolated size midpoint");
        CHECK(EQ(mid.alpha, 0.5), "interpolated alpha midpoint");
        CHECK(mid.zIndex == 9, "zIndex switches at >=0.5");

        /* one-sided interpolation returns the present attributes */
        NSCollectionViewLayoutAttributes *none = nil;
        NSCollectionViewLayoutAttributes *only = [t interpolatedLayoutAttributesFromLayoutAttributes:fa toLayoutAttributes:none progress:0.5];
        CHECK(EQ(only.frame.size.width, 100) && EQ(only.alpha, 0.0), "one-sided interpolation copies present attrs");
        CHECK([t interpolatedLayoutAttributesFromLayoutAttributes:none toLayoutAttributes:none progress:0.5] == nil, "both nil -> nil");

        /* content size interpolation uses progress (both flow layouts give zero here) */
        CHECK(NSEqualSizes(t.collectionViewContentSize, NSZeroSize), "content size interpolates (0 between two empty layouts)");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
