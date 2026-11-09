/* test_nstextalternatives.m — NSTextAlternatives value object. */
#import "../src/NSTextAlternatives.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTextAlternatives *a = [[NSTextAlternatives alloc] initWithPrimaryString:@"teh"
                                                               alternativeStrings:@[@"the", @"ten", @"tech"]];
        CHECK([a.primaryString isEqualToString:@"teh"], "primary string stored");
        CHECK(a.alternativeStrings.count == 3, "three alternatives");
        CHECK([a.alternativeStrings[0] isEqualToString:@"the"], "first alternative");
        CHECK(!a.isLowConfidence, "not low confidence by default");

        a.lowConfidence = YES;
        CHECK(a.isLowConfidence, "low confidence set");

        /* nil-safe init */
        NSString *nilStr = nil; NSArray *nilArr = nil;
        NSTextAlternatives *e = [[NSTextAlternatives alloc] initWithPrimaryString:nilStr alternativeStrings:nilArr];
        CHECK([e.primaryString isEqualToString:@""], "nil primary -> empty");
        CHECK(e.alternativeStrings.count == 0, "nil alternatives -> empty array");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
