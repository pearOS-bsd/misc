/* test_nsfontmanager.m — singleton, conversion algebra, traits. */
#import "../src/NSFontManager.h"
#import "../src/NSFont.h"
#import <objc/runtime.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSFontManager *fm = [NSFontManager sharedFontManager];
        CHECK(fm != nil, "sharedFontManager exists");
        CHECK(fm == [NSFontManager sharedFontManager], "singleton identity");
        CHECK(sel_isEqual(fm.action, @selector(changeFont:)), "default action changeFont:");

        /* target/action/enabled */
        id obj = [NSObject new];
        fm.target = obj;
        CHECK(fm.target == obj, "target set");
        fm.action = @selector(copy);
        CHECK(sel_isEqual(fm.action, @selector(copy)), "action set");
        fm.enabled = NO;
        CHECK(!fm.isEnabled, "enabled cleared");
        fm.enabled = YES;

        /* selected font + multiple */
        NSFont *hv = [NSFont fontWithName:@"Helvetica" size:12.0];
        CHECK(hv != nil, "Helvetica loads");
        [fm setSelectedFont:hv isMultiple:YES];
        CHECK(fm.selectedFont == hv, "selectedFont set");
        CHECK(fm.isMultiple, "multiple set");

        /* toSize keeps the face, changes size */
        NSFont *big = [fm convertFont:hv toSize:24.0];
        CHECK(big.pointSize == 24.0, "convert toSize changes size");
        CHECK([big.familyName isEqualToString:hv.familyName], "convert toSize keeps family");

        /* traits: a bold face reports Bold and not Unbold */
        NSFont *bold = [fm convertFont:hv toHaveTrait:NSBoldFontMask];
        NSFontTraitMask bt = [fm traitsOfFont:bold];
        CHECK((bt & NSBoldFontMask) != 0, "bold face has NSBoldFontMask");
        CHECK((bt & NSUnboldFontMask) == 0, "bold face lacks NSUnboldFontMask");
        CHECK([fm weightOfFont:bold] > [fm weightOfFont:hv], "bold weighs more than regular");

        /* removing the bold trait returns to a non-bold face */
        NSFont *unbold = [fm convertFont:bold toNotHaveTrait:NSBoldFontMask];
        CHECK(([fm traitsOfFont:unbold] & NSBoldFontMask) == 0, "toNotHaveTrait clears bold");

        /* "un" trait routes through removal */
        NSFont *viaUn = [fm convertFont:bold toHaveTrait:NSUnboldFontMask];
        CHECK(([fm traitsOfFont:viaUn] & NSBoldFontMask) == 0, "NSUnboldFontMask removes bold");

        /* convertFontTraits normalizes conflicting masks */
        NSFontTraitMask norm = [fm convertFontTraits:(NSBoldFontMask | NSUnboldFontMask)];
        CHECK((norm & NSBoldFontMask) == 0, "convertFontTraits: un-trait wins");

        /* fontNamed:hasTraits: */
        CHECK([fm fontNamed:@"Helvetica-Bold" hasTraits:NSBoldFontMask], "Helvetica-Bold has Bold");
        CHECK(![fm fontNamed:@"Helvetica" hasTraits:NSBoldFontMask], "Helvetica lacks Bold");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
