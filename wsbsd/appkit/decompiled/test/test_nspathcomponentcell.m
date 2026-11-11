/* test_nspathcomponentcell.m — behaviour checks for NSPathComponentCell core */
#import "../src/NSPathComponentCell.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSPathComponentCell *c = [[NSPathComponentCell alloc] init];
        CHECK([c isKindOfClass:[NSTextFieldCell class]], "is an NSTextFieldCell");

        /* defaults */
        CHECK(c.image == nil, "image nil by default");
        CHECK(c.URL == nil, "URL nil by default");

        /* value model */
        id img = [NSObject new];
        c.image = (id)img;
        CHECK(c.image == img, "image stored");
        NSURL *u = [NSURL fileURLWithPath:@"/Users/x/Documents"];
        c.URL = u;
        CHECK([c.URL isEqual:u], "URL stored");

        /* inherited title via stringValue */
        c.stringValue = @"Documents";
        CHECK([c.stringValue isEqual:@"Documents"], "title via inherited stringValue");

        /* URL copy semantics */
        NSURL *u2 = [NSURL fileURLWithPath:@"/tmp"];
        c.URL = u2;
        CHECK([c.URL.path isEqual:@"/tmp"], "URL replaced");

        /* copy carries image + URL + title */
        NSPathComponentCell *cp = [c copy];
        CHECK([cp isKindOfClass:[NSPathComponentCell class]], "copy is an NSPathComponentCell");
        CHECK(cp.image == img && [cp.URL.path isEqual:@"/tmp"], "copy carries image + URL");
        CHECK([cp.stringValue isEqual:@"Documents"], "copy carries inherited title");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
