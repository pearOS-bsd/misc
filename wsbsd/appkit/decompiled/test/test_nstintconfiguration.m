/* test_nstintconfiguration.m — NSTintConfiguration factories. */
#import "../src/NSTintConfiguration.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTintConfiguration *def = NSTintConfiguration.defaultTintConfiguration;
        CHECK(def.baseTintColor == nil, "default has no base tint color");
        CHECK(def.adaptsToUserAccentColor, "default adapts to accent color");

        NSTintConfiguration *mono = NSTintConfiguration.monochromeTintConfiguration;
        CHECK(mono.baseTintColor == nil, "monochrome has no base tint color");
        CHECK(!mono.adaptsToUserAccentColor, "monochrome does not adapt to accent");

        id red = [NSObject new];
        NSTintConfiguration *fixed = [NSTintConfiguration tintConfigurationWithFixedColor:red];
        CHECK(fixed.baseTintColor == red, "fixed color stored");
        CHECK(!fixed.adaptsToUserAccentColor, "fixed color does not adapt to accent");
        CHECK(fixed.equivalentContentTintColor == red, "equivalent content tint mirrors base (core)");

        id blue = [NSObject new];
        NSTintConfiguration *pref = [NSTintConfiguration tintConfigurationWithPreferredColor:blue];
        CHECK(pref.baseTintColor == blue, "preferred color stored");
        CHECK(pref.adaptsToUserAccentColor, "preferred color adapts to accent");

        /* copy */
        NSTintConfiguration *c = [fixed copy];
        CHECK(c.baseTintColor == red && !c.adaptsToUserAccentColor, "copy carries fields");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
