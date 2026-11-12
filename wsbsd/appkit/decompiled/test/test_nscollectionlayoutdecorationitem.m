/* test_nscollectionlayoutdecorationitem.m */
#import "../src/NSCollectionLayoutDecorationItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSCollectionLayoutDecorationItem *d = [NSCollectionLayoutDecorationItem backgroundDecorationItemWithElementKind:@"bg"];
        CHECK([d isKindOfClass:[NSCollectionLayoutItem class]], "decoration is-a NSCollectionLayoutItem");
        CHECK([d.elementKind isEqual:@"bg"], "elementKind stored");
        CHECK(d.zIndex == 0, "zIndex 0 default (measured)");

        /* zIndex settable + inherited insets */
        d.zIndex = -1; CHECK(d.zIndex == -1, "zIndex set");
        d.contentInsets = NSDirectionalEdgeInsetsMake(2,2,2,2);
        CHECK(d.contentInsets.top == 2, "inherited contentInsets works");

        /* NSCopying */
        NSCollectionLayoutDecorationItem *c = [d copy];
        CHECK([c.elementKind isEqual:@"bg"] && c.zIndex == -1 && c.contentInsets.top == 2, "copy preserves state");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
