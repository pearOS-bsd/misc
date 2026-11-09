/* test_nscolor.m — NSColor component-based core: components, HSB, conversion. */
#import "../src/NSColor.h"
#import <math.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)
#define CLOSE(a,b) (fabs((a)-(b)) < 1e-6)

int main(void)
{
    @autoreleasepool {
        NSColor *r = [NSColor colorWithSRGBRed:1.0 green:0.0 blue:0.0 alpha:1.0];
        CHECK(r.type == NSColorTypeComponentBased, "sRGB color is component-based");
        CHECK(r.colorSpace.colorSpaceModel == NSColorSpaceModelRGB, "backing space is RGB");
        CHECK(r.numberOfComponents == 4, "RGBA has 4 components");
        CHECK(CLOSE(r.redComponent, 1.0) && CLOSE(r.greenComponent, 0.0) && CLOSE(r.blueComponent, 0.0),
              "red component accessors");
        CHECK(CLOSE(r.alphaComponent, 1.0), "alpha component");

        /* RGB -> HSB: pure red is hue 0, saturation 1, brightness 1 */
        CHECK(CLOSE(r.hueComponent, 0.0) && CLOSE(r.saturationComponent, 1.0) && CLOSE(r.brightnessComponent, 1.0),
              "pure red HSB = (0,1,1)");

        /* HSB round trip: hue 1/3 (green), full sat/bri */
        NSColor *g = [NSColor colorWithHue:(1.0/3.0) saturation:1.0 brightness:1.0 alpha:1.0];
        CHECK(CLOSE(g.redComponent, 0.0) && CLOSE(g.greenComponent, 1.0) && CLOSE(g.blueComponent, 0.0),
              "hue 1/3 is pure green");

        /* named colors */
        CHECK(CLOSE([NSColor whiteColor].whiteComponent, 1.0), "whiteColor white=1");
        CHECK(CLOSE([NSColor blackColor].whiteComponent, 0.0), "blackColor white=0");
        CHECK(CLOSE([NSColor clearColor].alphaComponent, 0.0), "clearColor alpha=0");
        CHECK([NSColor grayColor].colorSpace.colorSpaceModel == NSColorSpaceModelGray, "grayColor is a gray color");

        /* gray color: redComponent must raise */
        NSColor *gray = [NSColor colorWithWhite:0.5 alpha:1.0];
        CHECK(gray.numberOfComponents == 2, "grayA has 2 components");
        CHECK(CLOSE(gray.whiteComponent, 0.5), "gray whiteComponent");
        BOOL raised = NO;
        @try { (void)gray.redComponent; } @catch (NSException *e) { raised = YES; }
        CHECK(raised, "redComponent on gray color raises");

        /* luminance of white via RGB whiteComponent */
        CHECK(CLOSE([NSColor whiteColor].whiteComponent, 1.0), "white RGB luminance");
        CHECK(CLOSE(r.whiteComponent, 0.299), "pure red luminance = 0.299");

        /* colorWithAlphaComponent */
        NSColor *rt = [r colorWithAlphaComponent:0.25];
        CHECK(CLOSE(rt.alphaComponent, 0.25) && CLOSE(rt.redComponent, 1.0), "alpha override keeps color");

        /* conversion RGB -> Gray */
        NSColor *grayFromRed = [r colorUsingColorSpace:[NSColorSpace genericGrayColorSpace]];
        CHECK(grayFromRed != nil && CLOSE(grayFromRed.whiteComponent, 0.299), "RGB->Gray uses luminance");

        /* conversion Gray -> RGB */
        NSColor *rgbFromGray = [gray colorUsingColorSpace:[NSColorSpace sRGBColorSpace]];
        CHECK(rgbFromGray != nil && CLOSE(rgbFromGray.redComponent, 0.5) && CLOSE(rgbFromGray.greenComponent, 0.5),
              "Gray->RGB replicates white across channels");

        /* CGColor bridging */
        CHECK(r.CGColor != NULL, "CGColor built");
        CHECK(CGColorGetAlpha(r.CGColor) == 1.0, "CGColor alpha matches");

        /* equality */
        NSColor *r2 = [NSColor colorWithSRGBRed:1.0 green:0.0 blue:0.0 alpha:1.0];
        CHECK([r isEqual:r2], "equal RGBA colors are equal");
        CHECK(![r isEqual:gray], "RGB and gray colors not equal");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
