/* test — NSUserInterfaceCompressionOptions set algebra. */
#import "../src/NSUserInterfaceCompressionOptions.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSUserInterfaceCompressionOptions *empty = [[NSUserInterfaceCompressionOptions alloc] init];
        CHECK(empty.isEmpty, "empty options are empty");

        NSUserInterfaceCompressionOptions *hideText = NSUserInterfaceCompressionOptions.hideTextOption;
        NSUserInterfaceCompressionOptions *hideImages = NSUserInterfaceCompressionOptions.hideImagesOption;
        CHECK(!hideText.isEmpty, "a standard option is not empty");
        CHECK(![hideText isEqual:hideImages], "distinct standard options differ");
        CHECK([hideText isEqual:NSUserInterfaceCompressionOptions.hideTextOption], "same option equal");

        /* union */
        NSUserInterfaceCompressionOptions *both = [hideText optionsByAddingOptions:hideImages];
        CHECK([both containsOptions:hideText], "union contains hideText");
        CHECK([both containsOptions:hideImages], "union contains hideImages");
        CHECK([both intersectsOptions:hideText], "union intersects hideText");

        /* containsOptions is a superset test */
        CHECK(![hideText containsOptions:both], "single option does not contain the union");

        /* minus */
        NSUserInterfaceCompressionOptions *justImages = [both optionsByRemovingOptions:hideText];
        CHECK([justImages containsOptions:hideImages], "after removing hideText, images remain");
        CHECK(![justImages intersectsOptions:hideText], "removed option no longer present");

        /* standardOptions contains all four */
        NSUserInterfaceCompressionOptions *std = NSUserInterfaceCompressionOptions.standardOptions;
        CHECK([std containsOptions:NSUserInterfaceCompressionOptions.breakEqualWidthsOption], "standard has breakEqualWidths");
        CHECK([std containsOptions:NSUserInterfaceCompressionOptions.reduceMetricsOption], "standard has reduceMetrics");
        CHECK([std containsOptions:both], "standard contains hideText+hideImages");

        /* empty intersects nothing */
        CHECK(![empty intersectsOptions:std], "empty intersects nothing");

        /* copy */
        CHECK([[both copy] isEqual:both], "copy equals original");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
