/* test_nsimageview.m — NSImageView delegating packed enum flags to NSImageCell. */
#import "../src/NSImageView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSImageView *iv = [[NSImageView alloc] initWithFrame:CGRectMake(0, 0, 64, 64)];
        CHECK([iv.cell isKindOfClass:[NSImageCell class]], "cell is NSImageCell");

        iv.imageAlignment = NSImageAlignBottomRight;
        iv.imageScaling = NSImageScaleProportionallyUpOrDown;
        iv.imageFrameStyle = NSImageFrameGroove;
        CHECK(iv.imageAlignment == NSImageAlignBottomRight, "imageAlignment round-trips");
        CHECK(iv.imageScaling == NSImageScaleProportionallyUpOrDown, "imageScaling round-trips");
        CHECK(iv.imageFrameStyle == NSImageFrameGroove, "imageFrameStyle round-trips");

        /* packed into one word, independent of each other */
        CHECK(iv.imageAlignment == NSImageAlignBottomRight && iv.imageScaling == NSImageScaleProportionallyUpOrDown,
              "packed enum fields are independent");
        CHECK([(NSImageCell *)iv.cell imageFrameStyle] == NSImageFrameGroove, "stored on the cell");

        id img = [NSObject new];   /* NSImage stand-in */
        iv.image = img;
        CHECK(iv.image == img, "image round-trips (NSImage is stage2)");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
