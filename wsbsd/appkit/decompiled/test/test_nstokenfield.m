/* test_nstokenfield.m — NSTokenField over NSTokenFieldCell. */
#import "../src/NSTokenField.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTokenField *tf = [[NSTokenField alloc] initWithFrame:CGRectMake(0, 0, 160, 24)];
        CHECK([tf.cell isKindOfClass:[NSTokenFieldCell class]], "cell is NSTokenFieldCell");

        tf.stringValue = @"a,b,c";
        CHECK([tf.stringValue isEqualToString:@"a,b,c"], "inherits stringValue");

        tf.tokenStyle = NSTokenStyleRounded;
        CHECK(tf.tokenStyle == NSTokenStyleRounded, "tokenStyle round-trips");
        tf.tokenStyle = (NSTokenStyle)99;   /* invalid -> 0 */
        CHECK(tf.tokenStyle == NSTokenStyleDefault, "invalid tokenStyle falls back to default");

        tf.completionDelay = 0.4;
        CHECK(tf.completionDelay == 0.4, "completionDelay round-trips");

        /* default tokenizing set is non-nil (comma) */
        CHECK(tf.tokenizingCharacterSet != nil, "tokenizingCharacterSet has a default");
        CHECK([tf.tokenizingCharacterSet characterIsMember:','], "default set contains comma");
        tf.tokenizingCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@";"];
        CHECK([tf.tokenizingCharacterSet characterIsMember:';'], "custom tokenizing set round-trips");

        CHECK([tf isKindOfClass:[NSTextField class]], "NSTokenField is an NSTextField");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
