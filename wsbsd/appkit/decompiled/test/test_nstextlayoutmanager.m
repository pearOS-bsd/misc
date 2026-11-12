/* test_nstextlayoutmanager.m */
#import "../src/NSTextLayoutManager.h"
#import "../src/NSTextContentStorage.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

static NSInteger OFF(id<NSTextLocation> l) { return [(NSTextContentStorageLocation *)l offset]; }

int main(void) {
    @autoreleasepool {
        NSTextLayoutManager *m = [[NSTextLayoutManager alloc] init];

        /* measured defaults */
        CHECK(m.usesFontLeading, "usesFontLeading YES default");
        CHECK(!m.usesHyphenation, "usesHyphenation NO default");
        CHECK(!m.limitsLayoutForSuspiciousContents, "limits NO default");
        CHECK(m.textSelections == nil, "textSelections nil default");
        CHECK(m.textContentManager == nil, "textContentManager nil default");
        CHECK(m.textContainer == nil, "textContainer nil default");
        CHECK(CGRectEqualToRect(m.usageBoundsForTextContainer, CGRectZero), "usageBounds zero (layout stage2)");
        CHECK(m.delegate == nil, "delegate nil default");
        CHECK(m.documentRange == nil, "documentRange nil without content manager");

        /* setters */
        m.usesHyphenation = YES; CHECK(m.usesHyphenation, "usesHyphenation set");
        m.limitsLayoutForSuspiciousContents = YES; CHECK(m.limitsLayoutForSuspiciousContents, "limits set");
        id container = [NSObject new]; m.textContainer = (id)container;
        CHECK((id)m.textContainer == container, "textContainer set");
        m.textSelections = @[[NSObject new]];
        CHECK(m.textSelections.count == 1, "textSelections set");

        /* wired to a content storage => documentRange delegates to it */
        NSTextContentStorage *cs = [[NSTextContentStorage alloc] init];
        cs.attributedString = [[NSAttributedString alloc] initWithString:@"hello"];
        [cs addTextLayoutManager:m];
        [m setTextContentManager:cs];   /* real wiring is done by the content manager */
        CHECK(m.textContentManager == cs, "textContentManager wired");
        CHECK(m.documentRange != nil && OFF(m.documentRange.endLocation) == 5, "documentRange from content manager");

        /* NSTextContentManager tracks the layout manager */
        CHECK(cs.textLayoutManagers.count == 1 && cs.textLayoutManagers[0] == m, "content manager lists the layout manager");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
