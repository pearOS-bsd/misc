/* test_nstextselectionnavigation.m */
#import "../src/NSTextSelectionNavigation.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSTextSelectionNavigation *n = [[NSTextSelectionNavigation alloc] initWithDataSource:nil];

        /* measured defaults */
        CHECK(n.textSelectionDataSource == nil, "data source nil default");
        CHECK(n.allowsNonContiguousRanges, "allowsNonContiguousRanges YES default");
        CHECK(!n.rotatesCoordinateSystemForLayoutOrientation, "rotates NO default");

        /* enum values */
        CHECK(NSTextSelectionNavigationDirectionForward == 0 && NSTextSelectionNavigationDirectionDown == 5, "direction enum");
        CHECK(NSTextSelectionNavigationDestinationCharacter == 0 && NSTextSelectionNavigationDestinationWord == 1
              && NSTextSelectionNavigationDestinationDocument == 6, "destination enum");

        /* data source stored */
        id ds = [NSObject new];
        n.textSelectionDataSource = (id)ds;
        CHECK((id)n.textSelectionDataSource == ds, "data source set (weak)");

        /* flags settable */
        n.allowsNonContiguousRanges = NO; CHECK(!n.allowsNonContiguousRanges, "allowsNonContiguousRanges set");
        n.rotatesCoordinateSystemForLayoutOrientation = YES; CHECK(n.rotatesCoordinateSystemForLayoutOrientation, "rotates set");

        /* resolution is stage2: returns nil without a layout engine, no crash */
        NSTextSelection *dest = [n destinationSelectionForTextSelection:nil
                                                             direction:NSTextSelectionNavigationDirectionForward
                                                           destination:NSTextSelectionNavigationDestinationWord
                                                             extending:NO
                                                              confined:NO];
        CHECK(dest == nil, "destination resolution nil (stage2)");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
