/* test_nsfontdescriptor.m — NSFontDescriptor: attribute store + derivation. */
#import "../src/NSFontDescriptor.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSFontDescriptor *d = [NSFontDescriptor fontDescriptorWithName:@"Helvetica" size:18.0];
        CHECK([d.postscriptName isEqualToString:@"Helvetica"], "postscriptName from name:");
        CHECK(d.pointSize == 18.0, "pointSize from size:");
        CHECK([[d objectForKey:NSFontNameAttribute] isEqualToString:@"Helvetica"], "objectForKey name");
        CHECK(d.fontAttributes.count == 2, "two attributes stored");
        CHECK(d.symbolicTraits == 0, "no symbolic traits by default");

        /* adding attributes yields a new descriptor; original unchanged */
        NSFontDescriptor *d2 = [d fontDescriptorWithSize:24.0];
        CHECK(d2.pointSize == 24.0, "derived descriptor has new size");
        CHECK(d.pointSize == 18.0, "original descriptor unchanged (immutable)");
        CHECK([d2.postscriptName isEqualToString:@"Helvetica"], "derived keeps name");

        /* symbolic traits round-trip */
        NSFontSymbolicTraits bold = kCTFontTraitBold;
        NSFontDescriptor *db = [d fontDescriptorWithSymbolicTraits:bold];
        CHECK(db.symbolicTraits == bold, "symbolic traits set and read back");
        CHECK(d.symbolicTraits == 0, "original still has no traits");

        /* family */
        NSFontDescriptor *df = [d fontDescriptorWithFamily:@"Times New Roman"];
        CHECK([[df objectForKey:NSFontFamilyAttribute] isEqualToString:@"Times New Roman"], "family attribute added");

        /* arbitrary attribute dict */
        NSFontDescriptor *a = [NSFontDescriptor fontDescriptorWithFontAttributes:@{
            NSFontNameAttribute: @"Menlo", NSFontSizeAttribute: @11,
        }];
        CHECK([a.postscriptName isEqualToString:@"Menlo"] && a.pointSize == 11, "attributes dict round-trips");

        /* merge keeps old keys, overrides matching ones */
        NSFontDescriptor *m = [a fontDescriptorByAddingAttributes:@{ NSFontSizeAttribute: @14 }];
        CHECK(m.pointSize == 14 && [m.postscriptName isEqualToString:@"Menlo"],
              "merge overrides size, keeps name");

        /* equality */
        NSFontDescriptor *a2 = [NSFontDescriptor fontDescriptorWithFontAttributes:@{
            NSFontNameAttribute: @"Menlo", NSFontSizeAttribute: @11,
        }];
        CHECK([a isEqual:a2], "equal attribute sets -> equal descriptors");
        CHECK(![a isEqual:m], "different attributes -> not equal");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
