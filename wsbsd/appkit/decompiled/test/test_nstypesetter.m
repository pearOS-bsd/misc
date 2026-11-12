/* test_nstypesetter.m */
#import "../src/NSTypesetter.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* shared instance */
        NSTypesetter *s = [NSTypesetter sharedSystemTypesetter];
        CHECK(s != nil && s == [NSTypesetter sharedSystemTypesetter], "sharedSystemTypesetter singleton");
        CHECK([NSTypesetter sharedSystemTypesetterForBehavior:NSTypesetterBehavior_10_4] != nil, "sharedForBehavior non-nil");

        /* class default behavior */
        CHECK([NSTypesetter defaultTypesetterBehavior] == NSTypesetterBehavior_10_4, "defaultTypesetterBehavior 10_4");
        CHECK(NSTypesetterLatestBehavior == -1, "latest behavior -1");

        /* fresh instance measured defaults */
        NSTypesetter *t = [[NSTypesetter alloc] init];
        CHECK(t.usesFontLeading, "usesFontLeading YES default");
        CHECK(t.typesetterBehavior == NSTypesetterBehavior_10_4, "typesetterBehavior 10_4 default");
        CHECK(t.hyphenationFactor == 0.0f, "hyphenationFactor 0 default");
        CHECK(t.lineFragmentPadding == 0.0, "lineFragmentPadding 0 default");
        CHECK(t.bidiProcessingEnabled, "bidiProcessingEnabled YES default");
        CHECK(t.attributedString == nil, "attributedString nil default");

        /* setters */
        t.usesFontLeading = NO; CHECK(!t.usesFontLeading, "usesFontLeading set");
        t.typesetterBehavior = NSTypesetterBehavior_10_2; CHECK(t.typesetterBehavior == NSTypesetterBehavior_10_2, "behavior set");
        t.hyphenationFactor = 0.5f; CHECK(t.hyphenationFactor == 0.5f, "hyphenationFactor set");
        t.lineFragmentPadding = 5.0; CHECK(t.lineFragmentPadding == 5.0, "lineFragmentPadding set");
        t.bidiProcessingEnabled = NO; CHECK(!t.bidiProcessingEnabled, "bidi set");
        NSAttributedString *as = [[NSAttributedString alloc] initWithString:@"x"];
        t.attributedString = as; CHECK(t.attributedString == as, "attributedString set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
