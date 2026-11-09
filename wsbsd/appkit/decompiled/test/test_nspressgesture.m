/* test_nspressgesture.m — NSPressGestureRecognizer (: NSGestureRecognizer). */
#import "../src/NSPressGestureRecognizer.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSPressGestureRecognizer *p = [[NSPressGestureRecognizer alloc] initWithTarget:nil action:NULL];
        CHECK([p isKindOfClass:[NSGestureRecognizer class]], "is an NSGestureRecognizer");
        CHECK(p.minimumPressDuration == 0.5, "default minimumPressDuration 0.5");
        CHECK(p.allowableMovement == 10.0, "default allowableMovement 10");
        CHECK(p.buttonMask == 0x1, "default primary button");
        CHECK(p.numberOfTouchesRequired == 1, "default 1 touch");

        p.minimumPressDuration = 1.0;
        CHECK(p.minimumPressDuration == 1.0, "minimumPressDuration round-trips");
        p.allowableMovement = 25.0;
        CHECK(p.allowableMovement == 25.0, "allowableMovement round-trips");
        p.buttonMask = 0x2;
        CHECK(p.buttonMask == 0x2, "buttonMask round-trips");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
