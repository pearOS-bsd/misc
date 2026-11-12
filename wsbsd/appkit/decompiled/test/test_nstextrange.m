/* test_nstextrange.m */
#import "../src/NSTextRange.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

/* a trivial integer-backed NSTextLocation */
@interface Loc : NSObject <NSTextLocation>
@property NSInteger v;
@end
@implementation Loc
- (NSComparisonResult)compare:(id<NSTextLocation>)o { NSInteger b = [(Loc *)o v]; return _v < b ? NSOrderedAscending : (_v > b ? NSOrderedDescending : NSOrderedSame); }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[Loc class]] && [(Loc *)o v] == _v; }
- (NSUInteger)hash { return (NSUInteger)_v; }
@end
static Loc *L(NSInteger v) { Loc *l = [Loc new]; l.v = v; return l; }
static NSInteger V(id<NSTextLocation> l) { return [(Loc *)l v]; }

int main(void) {
    @autoreleasepool {
        NSTextRange *r = [[NSTextRange alloc] initWithLocation:L(2) endLocation:L(5)];
        CHECK(V(r.location) == 2 && V(r.endLocation) == 5, "endpoints stored");
        CHECK(!r.isEmpty, "non-empty range");

        /* single-location init => empty range */
        NSTextRange *e = [[NSTextRange alloc] initWithLocation:L(3)];
        CHECK(e.isEmpty && V(e.location) == 3 && V(e.endLocation) == 3, "single-location empty range");

        /* nil endLocation => empty at location */
        NSTextRange *e2 = [[NSTextRange alloc] initWithLocation:L(7) endLocation:nil];
        CHECK(e2.isEmpty && V(e2.location) == 7, "nil endLocation => empty");

        /* reversed endpoints rejected */
        CHECK([[NSTextRange alloc] initWithLocation:L(5) endLocation:L(2)] == nil, "reversed range rejected");

        /* containsLocation: half-open [2,5) */
        CHECK([r containsLocation:L(2)], "contains start");
        CHECK([r containsLocation:L(4)], "contains interior");
        CHECK(![r containsLocation:L(5)], "does not contain endLocation");
        CHECK(![r containsLocation:L(1)], "does not contain before");

        NSTextRange *r2 = [[NSTextRange alloc] initWithLocation:L(4) endLocation:L(8)];
        CHECK([r intersectsWithTextRange:r2], "overlapping ranges intersect");

        NSTextRange *far = [[NSTextRange alloc] initWithLocation:L(20) endLocation:L(22)];
        CHECK(![r intersectsWithTextRange:far], "disjoint ranges do not intersect");

        /* touching ranges do not 'intersect' (zero-length overlap) */
        NSTextRange *touch = [[NSTextRange alloc] initWithLocation:L(5) endLocation:L(9)];
        CHECK(![r intersectsWithTextRange:touch], "touching ranges do not intersect");

        /* union */
        NSTextRange *u = [r textRangeByFormingUnionWithTextRange:r2];
        CHECK(V(u.location) == 2 && V(u.endLocation) == 8, "union = [min start, max end)");

        /* intersection */
        NSTextRange *i = [r textRangeByIntersectingWithTextRange:r2];
        CHECK(V(i.location) == 4 && V(i.endLocation) == 5, "intersection = [max start, min end)");
        CHECK([r textRangeByIntersectingWithTextRange:far] == nil, "disjoint intersection is nil");

        /* containsRange */
        NSTextRange *big = [[NSTextRange alloc] initWithLocation:L(0) endLocation:L(10)];
        CHECK([big containsRange:r], "superset contains subset");
        CHECK(![r containsRange:big], "subset does not contain superset");

        /* equality */
        CHECK([r isEqualToTextRange:[[NSTextRange alloc] initWithLocation:L(2) endLocation:L(5)]], "isEqualToTextRange");
        CHECK([r isEqual:[[NSTextRange alloc] initWithLocation:L(2) endLocation:L(5)]], "isEqual + hash");
        CHECK(![r isEqualToTextRange:r2], "unequal ranges");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
