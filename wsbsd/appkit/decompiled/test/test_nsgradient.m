/* test_nsgradient.m — NSGradient: stops + exact RGBA interpolation. */
#import "../src/NSGradient.h"
#import <math.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)
#define CLOSE(a,b) (fabs((a)-(b)) < 1e-6)

int main(void)
{
    @autoreleasepool {
        NSColor *black = [NSColor colorWithSRGBRed:0 green:0 blue:0 alpha:1];
        NSColor *white = [NSColor colorWithSRGBRed:1 green:1 blue:1 alpha:1];

        NSGradient *g = [[NSGradient alloc] initWithStartingColor:black endingColor:white];
        CHECK(g != nil, "two-color gradient built");
        CHECK(g.numberOfColorStops == 2, "two stops");

        /* stop accessors */
        NSColor *c; CGFloat loc;
        [g getColor:&c location:&loc atIndex:0];
        CHECK(CLOSE(loc, 0.0), "stop 0 at location 0");
        [g getColor:&c location:&loc atIndex:1];
        CHECK(CLOSE(loc, 1.0), "stop 1 at location 1");

        /* midpoint of black->white is gray 0.5 */
        NSColor *mid = [g interpolatedColorAtLocation:0.5];
        CHECK(CLOSE(mid.redComponent, 0.5) && CLOSE(mid.greenComponent, 0.5) && CLOSE(mid.blueComponent, 0.5),
              "midpoint is 0.5 gray");

        /* quarter point */
        NSColor *q = [g interpolatedColorAtLocation:0.25];
        CHECK(CLOSE(q.redComponent, 0.25), "quarter point is 0.25");

        /* clamp below/above */
        CHECK(CLOSE([g interpolatedColorAtLocation:-1.0].redComponent, 0.0), "clamp below -> first color");
        CHECK(CLOSE([g interpolatedColorAtLocation:2.0].redComponent, 1.0), "clamp above -> last color");

        /* three evenly spaced colors */
        NSColor *red = [NSColor colorWithSRGBRed:1 green:0 blue:0 alpha:1];
        NSColor *blue = [NSColor colorWithSRGBRed:0 green:0 blue:1 alpha:1];
        NSGradient *g3 = [[NSGradient alloc] initWithColors:@[red, white, blue]];
        CHECK(g3.numberOfColorStops == 3, "three stops");
        [g3 getColor:&c location:&loc atIndex:1];
        CHECK(CLOSE(loc, 0.5), "middle stop auto-located at 0.5");
        /* at 0.25: halfway red->white = (1, 0.5, 0.5) */
        NSColor *rw = [g3 interpolatedColorAtLocation:0.25];
        CHECK(CLOSE(rw.redComponent, 1.0) && CLOSE(rw.greenComponent, 0.5) && CLOSE(rw.blueComponent, 0.5),
              "0.25 is halfway red->white");

        /* custom locations */
        CGFloat locs[2] = {0.2, 0.8};
        NSGradient *gc = [[NSGradient alloc] initWithColors:@[black, white] atLocations:locs colorSpace:[NSColorSpace sRGBColorSpace]];
        CHECK(CLOSE([gc interpolatedColorAtLocation:0.2].redComponent, 0.0), "at first custom loc -> first color");
        CHECK(CLOSE([gc interpolatedColorAtLocation:0.5].redComponent, 0.5), "mid of [0.2,0.8] -> 0.5");
        CHECK(CLOSE([gc interpolatedColorAtLocation:0.1].redComponent, 0.0), "below first custom loc clamps");

        /* out-of-range stop index raises */
        BOOL raised = NO;
        @try { [g getColor:&c location:&loc atIndex:5]; } @catch (NSException *e) { raised = YES; }
        CHECK(raised, "out-of-range stop index raises");

        /* equality + copy */
        NSGradient *g2 = [[NSGradient alloc] initWithStartingColor:black endingColor:white];
        CHECK([g isEqual:g2], "identical gradients equal");
        CHECK([[g copy] isEqual:g], "copy equals original");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
