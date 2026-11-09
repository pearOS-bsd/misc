/* test_nsfont.m — NSFont: CTFont-backed metrics and construction. */
#import "../src/NSFont.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSFont *sys = [NSFont systemFontOfSize:13.0];
        CHECK(sys != nil, "systemFontOfSize: builds a font");
        CHECK(sys.pointSize == 13.0, "pointSize matches request");
        CHECK(sys.CTFont != NULL, "backing CTFont present");
        CHECK(sys.fontName.length > 0, "fontName non-empty");
        CHECK(sys.familyName.length > 0, "familyName non-empty");

        /* metrics are self-consistent */
        CHECK(sys.ascender > 0, "ascender positive");
        CHECK(sys.descender < 0, "descender negative (NSFont convention)");
        CHECK(sys.capHeight > 0 && sys.xHeight > 0, "cap/x height positive");
        CHECK(sys.capHeight > sys.xHeight, "capHeight > xHeight");
        CHECK(sys.numberOfGlyphs > 0, "font has glyphs");
        CHECK(!CGRectIsEmpty(sys.boundingRectForFont), "boundingRectForFont non-empty");

        /* default size fallback */
        NSFont *dflt = [NSFont systemFontOfSize:0];
        CHECK(dflt.pointSize == 13.0, "size 0 falls back to 13pt");

        /* named font */
        NSFont *hel = [NSFont fontWithName:@"Helvetica" size:24.0];
        CHECK(hel != nil, "fontWithName:Helvetica builds");
        CHECK(hel.pointSize == 24.0, "named font point size");
        CHECK([hel.familyName isEqualToString:@"Helvetica"], "Helvetica family name");

        /* monospace detection */
        NSFont *mono = [NSFont fontWithName:@"Menlo-Regular" size:12.0];
        if (mono) CHECK(mono.isFixedPitch, "Menlo is fixed pitch");
        else CHECK(1, "Menlo unavailable; skip fixed-pitch check");

        /* bold is heavier: compare via display name containing Bold or distinct from regular */
        NSFont *bold = [NSFont boldSystemFontOfSize:13.0];
        CHECK(bold != nil && bold.pointSize == 13.0, "boldSystemFont builds at size");
        CHECK(![bold.fontName isEqualToString:sys.fontName], "bold system font differs from regular");

        /* equality */
        NSFont *sys2 = [NSFont systemFontOfSize:13.0];
        CHECK([sys isEqual:sys2], "two 13pt system fonts are equal");
        CHECK(![sys isEqual:hel], "system and Helvetica not equal");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
