/* test_nsmaggesture.m — NSMagnificationGestureRecognizer (: NSGestureRecognizer). */
#import "../src/NSMagnificationGestureRecognizer.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSMagnificationGestureRecognizer *m = [[NSMagnificationGestureRecognizer alloc] initWithTarget:nil action:NULL];
        CHECK([m isKindOfClass:[NSGestureRecognizer class]], "is an NSGestureRecognizer");
        CHECK(m.magnification == 0.0, "default magnification 0");
        m.magnification = 1.5;
        CHECK(m.magnification == 1.5, "magnification round-trips");
        m.magnification = -0.25;
        CHECK(m.magnification == -0.25, "negative magnification (pinch in) round-trips");
        CHECK(m.state == NSGestureRecognizerStatePossible, "inherits base state");
        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
