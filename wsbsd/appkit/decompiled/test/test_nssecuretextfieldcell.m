/* test_nssecuretextfieldcell.m */
#import "../src/NSSecureTextFieldCell.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSSecureTextFieldCell *c = [[NSSecureTextFieldCell alloc] initTextCell:@"pw"];
        CHECK([c isKindOfClass:[NSTextFieldCell class]], "is-a NSTextFieldCell");
        CHECK([c.stringValue isEqual:@"pw"], "title stored");
        CHECK(c.echosBullets, "echosBullets YES default (measured)");

        c.echosBullets = NO;
        CHECK(!c.echosBullets, "echosBullets set");

        NSSecureTextFieldCell *c2 = [[NSSecureTextFieldCell alloc] init];
        CHECK(c2.echosBullets, "plain init also echosBullets YES");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
