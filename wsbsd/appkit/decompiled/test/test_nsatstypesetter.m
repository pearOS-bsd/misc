/* test_nsatstypesetter.m */
#import "../src/NSATSTypesetter.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSATSTypesetter *t = [NSATSTypesetter sharedTypesetter];
        CHECK(t != nil, "sharedTypesetter exists");
        CHECK(t == [NSATSTypesetter sharedTypesetter], "sharedTypesetter singleton");
        CHECK([t isKindOfClass:[NSTypesetter class]], "is an NSTypesetter");

        /* inherits the base config defaults (measured) */
        CHECK(t.usesFontLeading, "inherits usesFontLeading YES");
        CHECK(t.typesetterBehavior == NSTypesetterBehavior_10_4, "inherits behavior 10_4");
        CHECK(t.bidiProcessingEnabled, "inherits bidiProcessingEnabled YES");

        /* inherited setters work on the instance */
        NSATSTypesetter *t2 = [[NSATSTypesetter alloc] init];
        t2.hyphenationFactor = 0.25f;
        CHECK(t2.hyphenationFactor == 0.25f, "inherited setter works");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
