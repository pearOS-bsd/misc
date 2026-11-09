/* test_nsshadow.m — NSShadow value object. */
#import "../src/NSShadow.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSShadow *s = [[NSShadow alloc] init];
        CHECK(s.shadowOffset.width == 0 && s.shadowOffset.height == 0, "default offset {0,0}");
        CHECK(s.shadowBlurRadius == 0.0, "default blur 0");
        CHECK(s.shadowColor == nil, "default color nil");

        s.shadowOffset = CGSizeMake(3, -4);
        s.shadowBlurRadius = 5.0;
        s.shadowColor = [NSColor colorWithSRGBRed:0 green:0 blue:0 alpha:0.5];
        CHECK(s.shadowOffset.width == 3 && s.shadowOffset.height == -4, "offset set");
        CHECK(s.shadowBlurRadius == 5.0, "blur set");
        CHECK(s.shadowColor != nil, "color set");

        /* copy independence */
        NSShadow *c = [s copy];
        CHECK(c.shadowOffset.width == 3 && c.shadowBlurRadius == 5.0, "copy carries values");
        c.shadowBlurRadius = 9.0;
        CHECK(s.shadowBlurRadius == 5.0, "copy is independent");

        /* initWithShadow: */
        NSShadow *d = [[NSShadow alloc] initWithShadow:s];
        CHECK([d isEqual:s], "initWithShadow: produces an equal shadow");

        /* equality sensitivity */
        NSShadow *e = [s copy];
        CHECK([e isEqual:s], "copy equal to original");
        e.shadowOffset = CGSizeMake(0, 0);
        CHECK(![e isEqual:s], "differing offset breaks equality");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
