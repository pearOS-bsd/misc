/* test_nstextlist.m — NSTextList: marker rendering per format token. */
#import "../src/NSTextList.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)
#define EQ(s, lit) ([(s) isEqualToString:(lit)])

int main(void)
{
    @autoreleasepool {
        NSTextList *dec = [[NSTextList alloc] initWithMarkerFormat:@"{decimal}." options:0];
        CHECK(dec.ordered, "decimal list is ordered");
        CHECK(EQ([dec markerForItemNumber:1], @"1."), "decimal item 1 -> 1.");
        CHECK(EQ([dec markerForItemNumber:42], @"42."), "decimal item 42 -> 42.");
        CHECK(dec.startingItemNumber == 1, "default starting item 1");

        NSTextList *lr = [[NSTextList alloc] initWithMarkerFormat:@"{lower-roman})" options:0];
        CHECK(lr.ordered, "roman list is ordered");
        CHECK(EQ([lr markerForItemNumber:1], @"i)"), "roman 1 -> i");
        CHECK(EQ([lr markerForItemNumber:4], @"iv)"), "roman 4 -> iv");
        CHECK(EQ([lr markerForItemNumber:9], @"ix)"), "roman 9 -> ix");
        CHECK(EQ([lr markerForItemNumber:2024], @"mmxxiv)"), "roman 2024 -> mmxxiv");

        NSTextList *ur = [[NSTextList alloc] initWithMarkerFormat:@"{upper-roman}" options:0];
        CHECK(EQ([ur markerForItemNumber:14], @"XIV"), "upper roman 14 -> XIV");

        NSTextList *la = [[NSTextList alloc] initWithMarkerFormat:@"{lower-alpha}." options:0];
        CHECK(EQ([la markerForItemNumber:1], @"a."), "alpha 1 -> a");
        CHECK(EQ([la markerForItemNumber:26], @"z."), "alpha 26 -> z");
        CHECK(EQ([la markerForItemNumber:27], @"aa."), "alpha 27 -> aa");
        CHECK(EQ([la markerForItemNumber:28], @"ab."), "alpha 28 -> ab");

        NSTextList *ua = [[NSTextList alloc] initWithMarkerFormat:@"{upper-alpha}" options:0];
        CHECK(EQ([ua markerForItemNumber:2], @"B"), "upper alpha 2 -> B");

        /* unordered glyph bullets */
        NSTextList *disc = [[NSTextList alloc] initWithMarkerFormat:@"{disc}" options:0];
        CHECK(!disc.ordered, "disc list is unordered");
        CHECK(EQ([disc markerForItemNumber:5], @"•"), "disc renders bullet regardless of number");

        NSTextList *hy = [[NSTextList alloc] initWithMarkerFormat:@"{hyphen}" options:0];
        CHECK(!hy.ordered && EQ([hy markerForItemNumber:1], @"-"), "hyphen bullet");

        /* options + starting number */
        NSTextList *o = [[NSTextList alloc] initWithMarkerFormat:@"{decimal}" options:NSTextListPrependEnclosingMarker];
        CHECK(o.listOptions == NSTextListPrependEnclosingMarker, "listOptions stored");
        o.startingItemNumber = 5;
        CHECK(o.startingItemNumber == 5, "starting item number set");

        /* copy + equality */
        CHECK([[dec copy] isEqual:dec], "copy equals original");
        CHECK(![dec isEqual:lr], "different formats not equal");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
