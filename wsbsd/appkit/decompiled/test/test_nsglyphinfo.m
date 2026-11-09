/* test_nsglyphinfo.m — NSGlyphInfo CID + glyph-name constructors. */
#import "../src/NSGlyphInfo.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSGlyphInfo *cid = [NSGlyphInfo glyphInfoWithCharacterIdentifier:1234
                                                              collection:NSAdobeJapan1CharacterCollection
                                                              baseString:@"A"];
        CHECK(cid != nil, "CID glyph info built");
        CHECK(cid.characterIdentifier == 1234, "character identifier stored");
        CHECK(cid.characterCollection == NSAdobeJapan1CharacterCollection, "collection stored");
        CHECK([cid.baseString isEqualToString:@"A"], "base string stored");
        CHECK(cid.glyphName == nil, "CID info has no glyph name");

        NSGlyphInfo *named = [NSGlyphInfo glyphInfoWithGlyphName:@"ampersand" forFont:nil baseString:@"&"];
        CHECK(named != nil, "named glyph info built");
        CHECK([named.glyphName isEqualToString:@"ampersand"], "glyph name stored");
        CHECK([named.baseString isEqualToString:@"&"], "named base string stored");
        CHECK(named.characterCollection == NSIdentityMappingCharacterCollection, "named uses identity collection");

        /* empty base string -> nil */
        CHECK([NSGlyphInfo glyphInfoWithCharacterIdentifier:1 collection:0 baseString:@""] == nil,
              "empty base string -> nil");
        CHECK([NSGlyphInfo glyphInfoWithGlyphName:@"" forFont:nil baseString:@"x"] == nil,
              "empty glyph name -> nil");

        /* equality + copy */
        NSGlyphInfo *cid2 = [NSGlyphInfo glyphInfoWithCharacterIdentifier:1234
                                                              collection:NSAdobeJapan1CharacterCollection
                                                              baseString:@"A"];
        CHECK([cid isEqual:cid2], "equal CID infos are equal");
        CHECK([[cid copy] isEqual:cid], "copy equals original");
        CHECK(![cid isEqual:named], "CID and named not equal");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
