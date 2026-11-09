/* test — NSTitlebarAccessoryViewController. */
#import "../src/NSTitlebarAccessoryViewController.h"
#import "../src/NSView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTitlebarAccessoryViewController *ac = [[NSTitlebarAccessoryViewController alloc] initWithNibName:nil bundle:nil];
        CHECK([ac isKindOfClass:[NSViewController class]], "is an NSViewController");
        CHECK(ac.layoutAttribute == NSLayoutAttributeBottom, "default layout attribute Bottom");
        CHECK(!ac.isHidden, "not hidden by default");
        CHECK(ac.automaticallyAdjustsSize, "automaticallyAdjustsSize default YES");
        CHECK(ac.fullScreenMinHeight == 0.0, "full-screen min height 0 by default");

        ac.layoutAttribute = NSLayoutAttributeRight;
        ac.hidden = YES;
        ac.fullScreenMinHeight = 44.0;
        ac.automaticallyAdjustsSize = NO;
        CHECK(ac.layoutAttribute == NSLayoutAttributeRight, "layout attribute set");
        CHECK(ac.isHidden, "hidden set");
        CHECK(ac.fullScreenMinHeight == 44.0, "full-screen min height set");
        CHECK(!ac.automaticallyAdjustsSize, "automaticallyAdjustsSize set NO");

        /* inherits lazy view */
        (void)ac.view;
        CHECK(ac.isViewLoaded, "inherits NSViewController lazy view");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
