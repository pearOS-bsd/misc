/* test_nscollectionviewlayout.m — behaviour checks for the abstract base core */
#import "../src/NSCollectionViewLayout.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface NSCollectionViewLayout (TestInternals)
- (void)_setPrepared:(BOOL)p;
- (BOOL)_isPrepared;
- (Class)_decorationViewClassForKind:(NSString *)kind;
- (id)_decorationViewNibForKind:(NSString *)kind;
@end

@interface DecoView : NSObject @end
@implementation DecoView @end

int main(void) {
    @autoreleasepool {
        /* class hook */
        CHECK([NSCollectionViewLayout layoutAttributesClass] == [NSCollectionViewLayoutAttributes class],
              "layoutAttributesClass is NSCollectionViewLayoutAttributes");

        NSCollectionViewLayout *l = [[NSCollectionViewLayout alloc] init];
        CHECK(l.collectionView == nil, "collectionView nil until installed");

        /* base override points return empty/nil/zero */
        CHECK(NSEqualSizes(l.collectionViewContentSize, NSZeroSize), "base content size zero");
        CHECK([l layoutAttributesForElementsInRect:NSMakeRect(0,0,10,10)].count == 0, "base rect query empty");
        NSIndexPath *ip = [NSIndexPath indexPathWithIndex:0];
        CHECK([l layoutAttributesForItemAtIndexPath:ip] == nil, "base item attrs nil");
        CHECK([l layoutAttributesForSupplementaryViewOfKind:@"h" atIndexPath:ip] == nil, "base supp attrs nil");
        CHECK([l layoutAttributesForDecorationViewOfKind:@"bg" atIndexPath:ip] == nil, "base deco attrs nil");
        CHECK(![l shouldInvalidateLayoutForBoundsChange:NSMakeRect(0,0,5,5)], "base bounds-change NO");

        /* prepared flag + invalidateLayout */
        [l _setPrepared:YES];
        CHECK([l _isPrepared], "prepared set");
        [l invalidateLayout];
        CHECK(![l _isPrepared], "invalidateLayout clears prepared");

        /* decoration registration: class, override by nib, and nil removal */
        [l registerClass:[DecoView class] forDecorationViewOfKind:@"bg"];
        CHECK([l _decorationViewClassForKind:@"bg"] == [DecoView class], "decoration class registered");
        id nib = [NSObject new];
        [l registerNib:nib forDecorationViewOfKind:@"bg"];
        CHECK([l _decorationViewNibForKind:@"bg"] == nib, "nib registered");
        CHECK([l _decorationViewClassForKind:@"bg"] == nil, "nib registration clears class for same kind");
        [l registerNib:nil forDecorationViewOfKind:@"bg"];
        CHECK([l _decorationViewNibForKind:@"bg"] == nil, "nil nib removes registration");

        /* invalidationContextClass tolerant when the class is absent */
        (void)[NSCollectionViewLayout invalidationContextClass];
        CHECK(1, "invalidationContextClass safe");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
