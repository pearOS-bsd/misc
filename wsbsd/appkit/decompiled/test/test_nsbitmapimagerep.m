/* test_nsbitmapimagerep.m — NSBitmapImageRep over a CGImage. */
#import "../src/NSBitmapImageRep.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

static CGImageRef MakeImage(size_t w, size_t h)
{
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, w * 4, cs,
                        (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(cs);
    CGImageRef img = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return img;
}

int main(void)
{
    @autoreleasepool {
        CGImageRef img = MakeImage(40, 20);
        NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:img];
        CHECK(rep != nil, "rep built from CGImage");
        CHECK([rep isKindOfClass:[NSImageRep class]], "is an NSImageRep");
        CHECK(rep.pixelsWide == 40 && rep.pixelsHigh == 20, "pixel dims from CGImage");
        CHECK(rep.size.width == 40 && rep.size.height == 20, "size in points from CGImage");
        CHECK(rep.bitsPerSample == 8, "bitsPerSample 8");
        CHECK(rep.bitsPerPixel == 32, "bitsPerPixel 32 (RGBA8)");
        CHECK(rep.samplesPerPixel == 4, "samplesPerPixel 4");
        CHECK(rep.bytesPerRow == 160, "bytesPerRow = 40*4");
        CHECK(rep.bytesPerPlane == 160 * 20, "bytesPerPlane = bytesPerRow*height");
        CHECK(rep.hasAlpha, "RGBA image has alpha");
        CHECK(!rep.isPlanar, "CGImage-backed rep is not planar");
        CHECK(rep.numberOfPlanes == 1, "one plane");
        CHECK(rep.CGImage == img, "CGImage accessor returns backing image");

        /* premultiplied-last: AlphaFirst flag clear, nonpremultiplied clear */
        CHECK((rep.bitmapFormat & NSBitmapFormatAlphaFirst) == 0, "premultiplied-last is not alpha-first");
        CHECK((rep.bitmapFormat & NSBitmapFormatAlphaNonpremultiplied) == 0, "premultiplied, not non-premultiplied");

        CGImageRelease(img);

        CGImageRef nullImg = NULL;
        CHECK([[NSBitmapImageRep alloc] initWithCGImage:nullImg] == nil, "NULL CGImage -> nil");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
