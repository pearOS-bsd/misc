/* test_nsciimagerep.m */
#import "../src/NSCIImageRep.h"
#import <CoreImage/CoreImage.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        CIImage *red = [CIImage imageWithColor:[CIColor colorWithRed:1 green:0 blue:0]];
        CIImage *img = [red imageByCroppingToRect:CGRectMake(0, 0, 30, 40)];

        NSCIImageRep *r = [[NSCIImageRep alloc] initWithCIImage:img];
        CHECK([r isKindOfClass:[NSImageRep class]], "is NSImageRep");
        CHECK(r.CIImage == img, "CIImage is the same object");
        CHECK(r.size.width == 30 && r.size.height == 40, "size = extent size");
        CHECK(r.bitsPerSample == 0, "bitsPerSample 0 (measured)");
        CHECK(!r.isOpaque, "non-opaque (measured)");

        NSCIImageRep *r2 = [NSCIImageRep imageRepWithCIImage:img];
        CHECK(r2 != nil && r2.CIImage == img && r2.size.width == 30, "factory equivalent");

        /* a different extent gives a different size */
        CIImage *big = [red imageByCroppingToRect:CGRectMake(0, 0, 100, 10)];
        NSCIImageRep *r3 = [[NSCIImageRep alloc] initWithCIImage:big];
        CHECK(r3.size.width == 100 && r3.size.height == 10, "extent drives size");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
