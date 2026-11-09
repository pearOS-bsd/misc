/* test_nsimagerep.m — NSImageRep metadata + use as NSImage representation. */
#import "../src/NSImageRep.h"
#import "../src/NSImage.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSImageRep *r = [[NSImageRep alloc] init];
        r.size = CGSizeMake(128, 64);
        r.pixelsWide = 256;
        r.pixelsHigh = 128;
        r.bitsPerSample = 8;
        r.alpha = YES;
        r.opaque = NO;
        r.colorSpaceName = @"NSCalibratedRGBColorSpace";

        CHECK(r.size.width == 128 && r.size.height == 64, "size stored");
        CHECK(r.pixelsWide == 256 && r.pixelsHigh == 128, "pixel dims stored");
        CHECK(r.bitsPerSample == 8, "bitsPerSample stored");
        CHECK(r.hasAlpha, "hasAlpha set");
        CHECK(!r.isOpaque, "not opaque");
        CHECK([r.colorSpaceName isEqualToString:@"NSCalibratedRGBColorSpace"], "colorSpaceName stored");

        /* bitsPerSample is an 8-bit field */
        r.bitsPerSample = 16;
        CHECK(r.bitsPerSample == 16, "bitsPerSample 16");

        /* usable directly as an NSImage representation (it has -size) */
        NSImage *img = [[NSImage alloc] initWithSize:CGSizeZero];
        [img addRepresentation:(id<NSImageRepSizing>)r];
        CHECK(img.representations.count == 1, "rep added to image");
        CHECK(img.size.width == 128 && img.size.height == 64, "image derives size from the NSImageRep");

        /* copy */
        NSImageRep *c = [r copy];
        CHECK(c.pixelsWide == 256 && c.bitsPerSample == 16 && c.hasAlpha, "copy carries metadata");
        c.size = CGSizeMake(1, 1);
        CHECK(r.size.width == 128, "copy independent of original");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
