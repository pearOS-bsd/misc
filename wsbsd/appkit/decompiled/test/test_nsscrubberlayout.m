/* test_nsscrubberlayout.m — behaviour checks for NSScrubberLayout abstract base */
#import "../src/NSScrubberLayout.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface NSScrubberLayout (TestInternals)
- (void)_setScrubber:(id)s;
@end

int main(void) {
    @autoreleasepool {
        /* class hook */
        CHECK([NSScrubberLayout layoutAttributesClass] == [NSScrubberLayoutAttributes class],
              "layoutAttributesClass is NSScrubberLayoutAttributes");

        NSScrubberLayout *l = [[NSScrubberLayout alloc] init];
        CHECK(l.scrubber == nil, "scrubber nil until installed");

        /* measured base defaults */
        CHECK(!l.shouldInvalidateLayoutForSelectionChange, "base selChange NO");
        CHECK(!l.shouldInvalidateLayoutForHighlightChange, "base hlChange NO");
        CHECK(l.automaticallyMirrorsInRightToLeftLayout, "base mirrors RTL YES");
        CHECK(NSEqualSizes(l.scrubberContentSize, NSZeroSize), "base content size zero");

        /* base override points return empty/nil/zero */
        CHECK([l layoutAttributesForItemAtIndex:0] == nil, "base item attrs nil");
        CHECK([l layoutAttributesForItemsInRect:NSMakeRect(0,0,10,10)].count == 0, "base rect attrs empty");
        CHECK(!([l shouldInvalidateLayoutForChangeFromVisibleRect:NSZeroRect toVisibleRect:NSMakeRect(5,0,10,10)]), "base bounds-change NO");

        /* invalidate / prepare toggle without crashing */
        [l invalidateLayout];
        [l prepareLayout];
        CHECK(1, "invalidate/prepareLayout safe");

        /* _setScrubber back-link (internal) */
        CHECK([l respondsToSelector:@selector(_setScrubber:)], "has internal scrubber setter");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
