/* test_nscursor.m — NSCursor: image/hotSpot + current-cursor stack. */
#import "../src/NSCursor.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        id img = [NSObject new];   /* NSImage stand-in */
        NSCursor *c = [[NSCursor alloc] initWithImage:img hotSpot:CGPointMake(4, 8)];
        CHECK(c.image == img, "image from init");
        CHECK(c.hotSpot.x == 4 && c.hotSpot.y == 8, "hotSpot from init");

        [c set];
        CHECK([NSCursor currentCursor] == c, "set makes it the current cursor");

        NSCursor *c2 = [[NSCursor alloc] initWithImage:nil hotSpot:CGPointZero];
        [c2 push];
        CHECK([NSCursor currentCursor] == c2, "push makes the new cursor current");
        [NSCursor pop];
        CHECK([NSCursor currentCursor] == c, "pop restores the previous cursor");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
