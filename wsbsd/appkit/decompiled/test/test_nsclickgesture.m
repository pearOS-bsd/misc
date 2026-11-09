/* test_nsclickgesture.m — NSClickGestureRecognizer (: NSGestureRecognizer). */
#import "../src/NSClickGestureRecognizer.h"
#import <objc/runtime.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        id tgt = [NSObject new];
        NSClickGestureRecognizer *c = [[NSClickGestureRecognizer alloc] initWithTarget:tgt action:@selector(click:)];
        CHECK([c isKindOfClass:[NSGestureRecognizer class]], "is an NSGestureRecognizer");
        CHECK(c.target == tgt, "inherits target from init");
        CHECK(sel_isEqual(c.action, @selector(click:)), "inherits action from init");

        CHECK(c.numberOfClicksRequired == 1, "default 1 click");
        CHECK(c.buttonMask == 0x1, "default primary button");

        c.numberOfClicksRequired = 2;
        CHECK(c.numberOfClicksRequired == 2, "double-click round-trips");
        c.buttonMask = 0x2;
        CHECK(c.buttonMask == 0x2, "buttonMask round-trips");

        /* inherits state/enabled from the base */
        CHECK(c.state == NSGestureRecognizerStatePossible, "inherits base state");
        c.enabled = NO;
        CHECK(!c.isEnabled, "inherits enabled");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
