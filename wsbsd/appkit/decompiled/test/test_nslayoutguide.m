/* test_nslayoutguide.m — NSLayoutGuide value core. */
#import "../src/NSLayoutGuide.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSLayoutGuide *g = [[NSLayoutGuide alloc] init];
        CHECK([g.identifier isEqualToString:@""], "identifier defaults to empty");
        CHECK(CGRectEqualToRect(g.frame, CGRectZero), "frame defaults to zero");
        CHECK(g.owningView == nil, "no owning view by default");

        g.identifier = @"margins";
        CHECK([g.identifier isEqualToString:@"margins"], "identifier set");

        id view = [NSObject new];
        g.owningView = view;
        CHECK(g.owningView == view, "owning view set");

        /* engine glue installs the solved frame */
        [g _setFrame:CGRectMake(8, 8, 200, 20)];
        CHECK(g.frame.origin.x == 8 && g.frame.size.width == 200, "frame installed via engine glue");

        /* nil identifier coerces to empty */
        NSString *nilId = nil;
        g.identifier = nilId;
        CHECK([g.identifier isEqualToString:@""], "nil identifier -> empty string");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
