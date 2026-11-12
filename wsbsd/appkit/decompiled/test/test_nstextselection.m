/* test_nstextselection.m */
#import "../src/NSTextSelection.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface Loc : NSObject <NSTextLocation>
@property NSInteger v;
@end
@implementation Loc
- (NSComparisonResult)compare:(id<NSTextLocation>)o { NSInteger b = [(Loc *)o v]; return _v < b ? NSOrderedAscending : (_v > b ? NSOrderedDescending : NSOrderedSame); }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[Loc class]] && [(Loc *)o v] == _v; }
- (NSUInteger)hash { return (NSUInteger)_v; }
@end
static Loc *L(NSInteger v) { Loc *l = [Loc new]; l.v = v; return l; }
static NSTextRange *R(NSInteger a, NSInteger b) { return [[NSTextRange alloc] initWithLocation:L(a) endLocation:L(b)]; }

int main(void) {
    @autoreleasepool {
        NSTextRange *r = R(2,5);
        NSTextSelection *s = [[NSTextSelection alloc] initWithRange:r
                                                          affinity:NSTextSelectionAffinityDownstream
                                                       granularity:NSTextSelectionGranularityWord];
        /* measured defaults */
        CHECK(s.textRanges.count == 1, "one range");
        CHECK(s.granularity == NSTextSelectionGranularityWord, "granularity stored");
        CHECK(s.affinity == NSTextSelectionAffinityDownstream, "affinity stored");
        CHECK(!s.isTransient && !s.isLogical, "transient/logical NO default");
        CHECK(s.anchorPositionOffset == 0.0, "anchorPositionOffset 0 default");
        CHECK(s.typingAttributes == nil, "typingAttributes nil default");

        /* caret selection */
        NSTextSelection *caret = [[NSTextSelection alloc] initWithLocation:L(3) affinity:NSTextSelectionAffinityUpstream];
        CHECK(caret.textRanges.count == 1 && [caret.textRanges[0] isEmpty], "caret = one empty range");
        CHECK(caret.granularity == NSTextSelectionGranularityCharacter, "caret granularity Character");

        /* enum values */
        CHECK(NSTextSelectionAffinityUpstream == 0 && NSTextSelectionAffinityDownstream == 1, "affinity enum");
        CHECK(NSTextSelectionGranularityCharacter == 0 && NSTextSelectionGranularitySentence == 4, "granularity enum");

        /* containsLocation / textRangeContainingLocation */
        CHECK([s containsLocation:L(4)], "contains interior location");
        CHECK(![s containsLocation:L(5)], "excludes end location");
        CHECK([s textRangeContainingLocation:L(2)] == r, "returns the containing range");
        CHECK([s textRangeContainingLocation:L(9)] == nil, "nil for outside location");

        /* multi-range */
        NSTextSelection *multi = [[NSTextSelection alloc] initWithRanges:@[R(0,1), R(10,12)]
                                                               affinity:NSTextSelectionAffinityDownstream
                                                            granularity:NSTextSelectionGranularityCharacter];
        CHECK(multi.textRanges.count == 2, "two ranges");
        CHECK([multi containsLocation:L(11)] && ![multi containsLocation:L(5)], "multi contains checks each range");

        /* textSelectionWithTextRanges derives keeping affinity/granularity + flags */
        s.transient = YES; s.anchorPositionOffset = 3.5;
        NSTextSelection *d = [s textSelectionWithTextRanges:@[R(7,9)]];
        CHECK(d.textRanges.count == 1 && [d.textRanges[0] isEqualToTextRange:R(7,9)], "derived ranges");
        CHECK(d.granularity == NSTextSelectionGranularityWord && d.affinity == NSTextSelectionAffinityDownstream, "derived keeps gran/affinity");
        CHECK(d.isTransient && d.anchorPositionOffset == 3.5, "derived keeps flags/offset");

        /* equality */
        NSTextSelection *same = [[NSTextSelection alloc] initWithRange:R(2,5)
                                                             affinity:NSTextSelectionAffinityDownstream
                                                          granularity:NSTextSelectionGranularityWord];
        CHECK([s isEqualToTextSelection:same], "equal selections");
        NSTextSelection *diffGran = [[NSTextSelection alloc] initWithRange:R(2,5)
                                                                 affinity:NSTextSelectionAffinityDownstream
                                                              granularity:NSTextSelectionGranularityLine];
        CHECK(![s isEqualToTextSelection:diffGran], "granularity differs => unequal");

        /* setters */
        s.selectionAnchorLocation = L(2);
        CHECK([(Loc *)s.selectionAnchorLocation v] == 2, "anchor location set");
        s.typingAttributes = @{@"k": @1};
        CHECK(s.typingAttributes.count == 1, "typingAttributes set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
