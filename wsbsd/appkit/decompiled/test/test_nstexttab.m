/* test_nstexttab.m — NSTextTab: modern + legacy init, alignment mapping. */
#import "../src/NSTextTab.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTextTab *t = [[NSTextTab alloc] initWithTextAlignment:NSTextAlignmentCenter location:72.0 options:@{}];
        CHECK(t.alignment == NSTextAlignmentCenter, "modern alignment set");
        CHECK(t.location == 72.0, "location set");
        CHECK(t.options != nil && t.options.count == 0, "empty options");

        /* legacy type mapping */
        NSTextTab *l = [[NSTextTab alloc] initWithType:NSLeftTabStopType location:10];
        CHECK(l.alignment == NSTextAlignmentLeft, "left type -> left align");
        CHECK(l.options.count == 0, "left tab has no options");

        NSTextTab *r = [[NSTextTab alloc] initWithType:NSRightTabStopType location:20];
        CHECK(r.alignment == NSTextAlignmentRight, "right type -> right align");

        NSTextTab *c = [[NSTextTab alloc] initWithType:NSCenterTabStopType location:30];
        CHECK(c.alignment == NSTextAlignmentCenter, "center type -> center align");

        NSTextTab *d = [[NSTextTab alloc] initWithType:NSDecimalTabStopType location:40];
        CHECK(d.alignment == NSTextAlignmentRight, "decimal type -> right align");
        CHECK(d.options[NSTabColumnTerminatorsAttributeName] != nil, "decimal tab carries column terminators option");

        /* default init */
        NSTextTab *def = [[NSTextTab alloc] init];
        CHECK(def.alignment == NSTextAlignmentLeft && def.location == 0.0, "default is left tab at 0");

        /* copy + equality */
        NSTextTab *cp = [t copy];
        CHECK([cp isEqual:t], "copy equals original");
        CHECK(![l isEqual:r], "different tabs not equal");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
