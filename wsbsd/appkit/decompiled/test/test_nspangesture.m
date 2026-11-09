/* test_nspangesture.m — NSPanGestureRecognizer (: NSGestureRecognizer). */
#import "../src/NSPanGestureRecognizer.h"
#import <objc/runtime.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSPanGestureRecognizer *p = [[NSPanGestureRecognizer alloc] initWithTarget:nil action:@selector(pan:)];
        CHECK([p isKindOfClass:[NSGestureRecognizer class]], "is an NSGestureRecognizer");
        CHECK(sel_isEqual(p.action, @selector(pan:)), "inherits action");
        CHECK(p.buttonMask == 0x1, "default primary button");
        CHECK(p.numberOfTouchesRequired == 1, "default 1 touch");

        p.buttonMask = 0x4;
        CHECK(p.buttonMask == 0x4, "buttonMask round-trips");
        p.numberOfTouchesRequired = 2;
        CHECK(p.numberOfTouchesRequired == 2, "numberOfTouchesRequired round-trips");

        CHECK(p.state == NSGestureRecognizerStatePossible, "inherits base state");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
