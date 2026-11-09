/* test_nscolorspace.m — NSColorSpace: model mapping + component counts over CG. */
#import "../src/NSColorSpace.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSColorSpace *rgb = [NSColorSpace sRGBColorSpace];
        CHECK(rgb != nil, "sRGBColorSpace available");
        CHECK(rgb.colorSpaceModel == NSColorSpaceModelRGB, "sRGB model is RGB");
        CHECK(rgb.numberOfColorComponents == 3, "RGB has 3 components");
        CHECK(rgb.CGColorSpace != NULL, "backing CGColorSpace present");

        /* class singletons are cached (same pointer) */
        CHECK([NSColorSpace sRGBColorSpace] == rgb, "sRGBColorSpace is a cached singleton");

        NSColorSpace *gray = [NSColorSpace genericGrayColorSpace];
        CHECK(gray.colorSpaceModel == NSColorSpaceModelGray, "gray model is Gray (CG Monochrome)");
        CHECK(gray.numberOfColorComponents == 1, "Gray has 1 component");

        NSColorSpace *cmyk = [NSColorSpace genericCMYKColorSpace];
        CHECK(cmyk.colorSpaceModel == NSColorSpaceModelCMYK, "cmyk model is CMYK");
        CHECK(cmyk.numberOfColorComponents == 4, "CMYK has 4 components");

        NSColorSpace *p3 = [NSColorSpace displayP3ColorSpace];
        CHECK(p3.colorSpaceModel == NSColorSpaceModelRGB, "Display P3 model is RGB");
        CHECK(p3.numberOfColorComponents == 3, "P3 has 3 components");

        /* equality by underlying CGColorSpace */
        NSColorSpace *rgb2 = [[NSColorSpace alloc] initWithCGColorSpace:rgb.CGColorSpace];
        CHECK([rgb isEqual:rgb2], "two NSColorSpaces over the same CGColorSpace are equal");
        CHECK(![rgb isEqual:gray], "RGB and Gray color spaces are not equal");

        /* nil CGColorSpace -> nil instance */
        CGColorSpaceRef nullCS = NULL;
        CHECK([[NSColorSpace alloc] initWithCGColorSpace:nullCS] == nil, "init with NULL returns nil");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
