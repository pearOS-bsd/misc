/* test_nsrotationgesture.m — NSRotationGestureRecognizer (: NSGestureRecognizer). */
#import "../src/NSRotationGestureRecognizer.h"
#import <math.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSRotationGestureRecognizer *r = [[NSRotationGestureRecognizer alloc] initWithTarget:nil action:NULL];
        CHECK([r isKindOfClass:[NSGestureRecognizer class]], "is an NSGestureRecognizer");
        CHECK(r.rotation == 0.0, "default rotation 0");
        r.rotation = M_PI_2;
        CHECK(r.rotation == M_PI_2, "rotation (radians) round-trips");
        r.rotation = -M_PI;
        CHECK(r.rotation == -M_PI, "negative rotation round-trips");
        CHECK(r.state == NSGestureRecognizerStatePossible, "inherits base state");
        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
