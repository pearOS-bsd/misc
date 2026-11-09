/* test_nsappearance.m — NSAppearance: named singletons, matching, current. */
#import "../src/NSAppearance.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSAppearance *aqua = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
        CHECK(aqua != nil, "aqua appearance available");
        CHECK([aqua.name isEqualToString:NSAppearanceNameAqua], "name matches");
        CHECK([NSAppearance appearanceNamed:NSAppearanceNameAqua] == aqua, "appearanceNamed: is cached");
        CHECK(!aqua.allowsVibrancy, "aqua does not allow vibrancy");

        NSAppearance *vib = [NSAppearance appearanceNamed:NSAppearanceNameVibrantDark];
        CHECK(vib.allowsVibrancy, "vibrant dark allows vibrancy");

        NSAppearance *dark = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];

        /* best match: exact wins */
        NSArray *names = @[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ];
        CHECK([[dark bestMatchFromAppearancesWithNames:names] isEqualToString:NSAppearanceNameDarkAqua],
              "dark matches dark exactly");
        CHECK([[aqua bestMatchFromAppearancesWithNames:names] isEqualToString:NSAppearanceNameAqua],
              "aqua matches aqua exactly");

        /* family match when no exact: dark receiver, only vibrant candidates */
        NSArray *vibNames = @[ NSAppearanceNameVibrantLight, NSAppearanceNameVibrantDark ];
        CHECK([[dark bestMatchFromAppearancesWithNames:vibNames] isEqualToString:NSAppearanceNameVibrantDark],
              "dark receiver picks vibrant-dark by family");
        CHECK([[aqua bestMatchFromAppearancesWithNames:vibNames] isEqualToString:NSAppearanceNameVibrantLight],
              "light receiver picks vibrant-light by family");

        /* empty -> nil */
        CHECK([aqua bestMatchFromAppearancesWithNames:@[]] == nil, "empty candidate list -> nil");

        /* current drawing appearance stack */
        CHECK([NSAppearance currentDrawingAppearance] == nil, "no current appearance initially");
        __block BOOL inside = NO;
        [dark performAsCurrentDrawingAppearance:^{
            inside = ([NSAppearance currentDrawingAppearance] == dark);
        }];
        CHECK(inside, "current appearance is set inside the block");
        CHECK([NSAppearance currentDrawingAppearance] == nil, "current appearance restored after block");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
