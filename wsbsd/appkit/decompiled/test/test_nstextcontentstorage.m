/* test_nstextcontentstorage.m */
#import "../src/NSTextContentStorage.h"
#import "../src/NSTextParagraph.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

static NSInteger OFF(id<NSTextLocation> l) { return [(NSTextContentStorageLocation *)l offset]; }

int main(void) {
    @autoreleasepool {
        NSTextContentStorage *s = [[NSTextContentStorage alloc] init];

        /* measured defaults */
        CHECK(s.attributedString != nil && s.attributedString.length == 0, "empty attributedString default");
        CHECK(s.documentRange != nil && s.documentRange.isEmpty, "documentRange 0...0 empty default");
        CHECK([s isKindOfClass:[NSTextContentManager class]], "is NSTextContentManager");

        /* set content */
        s.attributedString = [[NSAttributedString alloc] initWithString:@"ab\ncd"];
        NSTextRange *dr = s.documentRange;
        CHECK(OFF(dr.location) == 0 && OFF(dr.endLocation) == 5, "documentRange spans 0..length");
        CHECK(!dr.isEmpty, "documentRange non-empty for content");

        /* offset arithmetic */
        CHECK([s offsetFromLocation:dr.location toLocation:dr.endLocation] == 5, "offsetFromLocation = length");
        id<NSTextLocation> l2 = [s locationFromLocation:dr.location withOffset:2];
        CHECK(OFF(l2) == 2, "locationFromLocation:withOffset:");
        CHECK([s locationFromLocation:dr.location withOffset:99] == nil, "out-of-range location -> nil");
        CHECK([s locationFromLocation:dr.location withOffset:-1] == nil, "negative location -> nil");

        /* paragraph split: "ab\ncd" -> 2 NSTextParagraph elements */
        NSArray<NSTextElement *> *els = [s textElementsForRange:dr];
        CHECK(els.count == 2, "two paragraph elements");
        CHECK([els[0] isKindOfClass:[NSTextParagraph class]], "elements are NSTextParagraph");
        NSAttributedString *first = [s attributedStringForTextElement:els[0]];
        CHECK([first.string isEqual:@"ab\n"], "first paragraph includes separator");
        NSAttributedString *second = [s attributedStringForTextElement:els[1]];
        CHECK([second.string isEqual:@"cd"], "second paragraph");

        /* element ranges line up */
        CHECK(OFF(els[0].elementRange.location) == 0 && OFF(els[0].elementRange.endLocation) == 3, "first element range 0..3");
        CHECK(OFF(els[1].elementRange.location) == 3 && OFF(els[1].elementRange.endLocation) == 5, "second element range 3..5");

        /* textParagraphForLocation */
        NSTextElement *p = [s textParagraphForLocation:[NSTextContentStorageLocation locationWithOffset:4]];
        CHECK([[s attributedStringForTextElement:p].string isEqual:@"cd"], "textParagraphForLocation finds the right paragraph");

        /* single-paragraph document */
        s.attributedString = [[NSAttributedString alloc] initWithString:@"one line"];
        CHECK([s textElementsForRange:s.documentRange].count == 1, "single paragraph => one element");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
