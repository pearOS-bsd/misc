/* test_nssecuretextfield.m */
#import "../src/NSSecureTextField.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSSecureTextField *f = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0,0,120,22)];
        CHECK([f isKindOfClass:[NSTextField class]], "is-a NSTextField");

        /* vends a secure cell */
        CHECK([NSSecureTextField cellClass] == [NSSecureTextFieldCell class], "cellClass is NSSecureTextFieldCell");
        CHECK([[NSSecureTextFieldCell class] isSubclassOfClass:[NSTextFieldCell class]], "secure cell is-a NSTextFieldCell");

        /* a standalone secure cell echoes bullets by default (measured in the cell) */
        NSSecureTextFieldCell *cell = [[NSSecureTextFieldCell alloc] init];
        CHECK(cell.echosBullets, "secure cell echosBullets YES");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
