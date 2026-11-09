/* test_nsscreen.m — NSScreen: screen table, fallback, display equality,
 * exact backing-coordinate conversion. */
#import "../src/NSScreen.h"
#import <math.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        /* Off-server fallback: exactly one screen. */
        [NSScreen _setScreens:nil];
        CHECK([NSScreen screens].count == 1, "fallback screen list has one entry");
        NSScreen *m = [NSScreen mainScreen];
        CHECK(m != nil, "mainScreen non-nil off-server");
        CHECK(m.backingScaleFactor == 2.0, "fallback backing scale is 2.0");
        CHECK(m.frame.size.width == 1440 && m.frame.size.height == 900, "fallback frame 1440x900");
        CHECK(m.visibleFrame.size.height == 875, "visibleFrame reserves 25pt menu bar");

        /* Backing conversion is exact arithmetic. */
        CGRect r = CGRectMake(10, 20, 100, 50);
        CGRect b = [m convertRectToBacking:r];
        CHECK(b.origin.x == 20 && b.size.width == 200 && b.size.height == 100,
              "convertRectToBacking scales by 2");
        CGRect back = [m convertRectFromBacking:b];
        CHECK(back.origin.x == 10 && back.size.width == 100, "FromBacking is the inverse");

        /* backingAlignedRect snaps edges to whole backing pixels. */
        CGRect frac = CGRectMake(10.1, 20.0, 100.0, 50.0); /* 20.2px -> 20px */
        CGRect al = [m backingAlignedRect:frac options:0];
        CHECK(fabs(al.origin.x - 10.0) < 1e-9, "backingAlignedRect snaps origin to 10.0 (20px/2)");

        /* deviceDescription carries NSScreenNumber. */
        CHECK([m.deviceDescription[@"NSScreenNumber"] integerValue] == m._screenNumber,
              "deviceDescription has NSScreenNumber");

        /* Equality is by display number, not pointer. */
        [NSScreen _setScreens:@[
            [[NSScreen alloc] _initWithScreenNumber:7 frame:CGRectMake(0,0,800,600)
                                       visibleFrame:CGRectMake(0,0,800,575)
                                 backingScaleFactor:1.0 depth:24],
            [[NSScreen alloc] _initWithScreenNumber:9 frame:CGRectMake(800,0,1000,600)
                                       visibleFrame:CGRectMake(800,0,1000,575)
                                 backingScaleFactor:2.0 depth:30],
        ]];
        CHECK([NSScreen screens].count == 2, "installed screen table has two entries");
        NSScreen *s7 = [NSScreen _screenForScreenNumber:7];
        NSScreen *s9 = [NSScreen _screenForScreenNumber:9];
        CHECK(s7 != nil && s9 != nil, "lookup by screen number");
        NSScreen *s7b = [[NSScreen alloc] _initWithScreenNumber:7 frame:CGRectZero
                                                   visibleFrame:CGRectZero
                                             backingScaleFactor:1.0 depth:24];
        CHECK([s7 isEqual:s7b], "two NSScreens for the same display are equal");
        CHECK(s7.hash == s7b.hash, "equal screens hash equal");
        CHECK(![s7 isEqual:s9], "different displays are not equal");

        /* deepestScreen = greatest depth. */
        CHECK([NSScreen deepestScreen] == s9, "deepestScreen picks the greatest depth");
        /* mainScreen = first installed. */
        CHECK([NSScreen mainScreen] == s7, "mainScreen is the first installed screen");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
