/* test_nsprintinfo.m — NSPrintInfo attribute-backed properties. */
#import "../src/NSPrintInfo.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSPrintInfo *pi = [[NSPrintInfo alloc] init];
        CHECK(pi.paperSize.width == 612 && pi.paperSize.height == 792, "default US Letter 612x792");
        CHECK(pi.orientation == NSPaperOrientationPortrait, "default portrait");
        CHECK(pi.scalingFactor == 1.0, "default scaling 1.0");
        CHECK(pi.leftMargin == 72 && pi.topMargin == 72, "default 1-inch margins");
        CHECK(pi.isHorizontallyCentered, "horizontally centered by default");
        CHECK(!pi.isVerticallyCentered, "not vertically centered by default");

        pi.paperSize = CGSizeMake(595, 842);   /* A4 */
        pi.orientation = NSPaperOrientationLandscape;
        pi.scalingFactor = 0.5;
        pi.leftMargin = 36;
        pi.verticallyCentered = YES;
        CHECK(pi.paperSize.width == 595 && pi.paperSize.height == 842, "A4 paper size set");
        CHECK(pi.orientation == NSPaperOrientationLandscape, "landscape set");
        CHECK(pi.scalingFactor == 0.5, "scaling set");
        CHECK(pi.leftMargin == 36, "left margin set");
        CHECK(pi.isVerticallyCentered, "vertically centered set");

        /* values are reflected in the dictionary */
        CHECK([pi.dictionary[@"NSScalingFactor"] doubleValue] == 0.5, "dictionary reflects scaling");

        /* shared singleton */
        CHECK([NSPrintInfo sharedPrintInfo] == [NSPrintInfo sharedPrintInfo], "shared is a singleton");
        [NSPrintInfo setSharedPrintInfo:pi];
        CHECK([NSPrintInfo sharedPrintInfo] == pi, "setSharedPrintInfo installs it");

        /* initWithDictionary overrides defaults */
        NSPrintInfo *custom = [[NSPrintInfo alloc] initWithDictionary:@{ @"NSScalingFactor": @2.0 }];
        CHECK(custom.scalingFactor == 2.0, "initWithDictionary overrides");
        CHECK(custom.leftMargin == 72, "non-overridden keys keep defaults");

        /* copy independence */
        NSPrintInfo *c = [pi copy];
        c.scalingFactor = 3.0;
        CHECK(pi.scalingFactor == 0.5, "copy independent");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
