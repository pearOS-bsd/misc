/* test_nstextlistelement.m */
#import "../src/NSTextListElement.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        id list = [NSObject new];   /* stand-in NSTextList */
        NSAttributedString *c = [[NSAttributedString alloc] initWithString:@"Item"];

        NSTextListElement *e = [NSTextListElement textListElementWithContents:c
                                                            markerAttributes:@{@"k": @1}
                                                                    textList:(id)list
                                                               childElements:nil];
        CHECK([e isKindOfClass:[NSTextParagraph class]], "is NSTextParagraph");
        CHECK(e.contents == c, "contents same object");
        CHECK((id)e.textList == list, "textList same object");
        CHECK(e.markerAttributes.count == 1, "markerAttributes stored");
        CHECK(e.childElements == nil, "childElements nil for leaf (measured)");
        CHECK(e.parentElement == nil, "parentElement nil default");
        CHECK(e.isRepresentedElement, "isRepresentedElement YES");
        CHECK(e.attributedString == c, "attributedString = contents (marker formatting stage2)");

        /* grouping element with children */
        NSTextListElement *child1 = [NSTextListElement textListElementWithContents:c markerAttributes:nil textList:(id)list childElements:nil];
        NSTextListElement *group = [NSTextListElement textListElementWithChildElements:@[child1] textList:(id)list nestingLevel:1];
        CHECK(group != nil, "grouping element created");
        CHECK(group.childElements.count == 1 && group.childElements[0] == child1, "grouping holds children");
        CHECK(group.contents == nil, "grouping has no direct contents");

        /* empty children => nil grouping element */
        CHECK([NSTextListElement textListElementWithChildElements:@[] textList:(id)list nestingLevel:0] == nil, "no children => nil grouping");

        /* parentElement settable */
        child1.parentElement = group;
        CHECK(child1.parentElement == group, "parentElement settable");

        /* designated init directly */
        NSTextListElement *d = [[NSTextListElement alloc] initWithParentElement:group textList:(id)list contents:c markerAttributes:nil childElements:nil];
        CHECK(d.parentElement == group && d.contents == c, "designated init stores parent + contents");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
