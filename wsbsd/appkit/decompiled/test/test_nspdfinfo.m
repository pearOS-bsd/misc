/* test_nspdfinfo.m */
#import "../src/NSPDFInfo.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSPDFInfo *p = [[NSPDFInfo alloc] init];
        /* measured defaults */
        CHECK(p.URL == nil, "URL nil default");
        CHECK(p.tagNames.count == 0, "tagNames empty default");
        CHECK(p.orientation == NSPaperOrientationPortrait, "orientation portrait default");
        CHECK(p.paperSize.width == 595.0 && p.paperSize.height == 842.0, "A4 paperSize default");
        CHECK(p.isFileExtensionHidden, "fileExtensionHidden YES default");
        CHECK(p.attributes != nil && p.attributes.count == 0, "attributes empty mutable default");

        /* attributes is mutable and the same object across reads */
        [p.attributes setObject:@1 forKey:@"k"];
        CHECK(p.attributes.count == 1, "attributes mutable");

        /* setters */
        p.URL = [NSURL fileURLWithPath:@"/tmp/x.pdf"];
        CHECK([p.URL.path isEqual:@"/tmp/x.pdf"], "URL set");
        p.tagNames = @[@"Red", @"Work"];
        CHECK(p.tagNames.count == 2, "tagNames set");
        p.orientation = NSPaperOrientationLandscape;
        CHECK(p.orientation == NSPaperOrientationLandscape, "orientation set");
        p.paperSize = CGSizeMake(612, 792);
        CHECK(p.paperSize.width == 612, "paperSize set");
        p.fileExtensionHidden = NO;
        CHECK(!p.isFileExtensionHidden, "fileExtensionHidden set");

        /* copy is deep for attributes */
        NSPDFInfo *c = [p copy];
        CHECK([c isKindOfClass:[NSPDFInfo class]], "copy is NSPDFInfo");
        CHECK([c.URL isEqual:p.URL] && c.tagNames.count == 2
              && c.orientation == NSPaperOrientationLandscape
              && c.paperSize.width == 612 && !c.isFileExtensionHidden, "copy carries scalars");
        CHECK(c.attributes != p.attributes, "copy attributes independent object");
        CHECK(c.attributes.count == 1, "copy attributes content preserved");
        [c.attributes setObject:@2 forKey:@"k2"];
        CHECK(p.attributes.count == 1, "mutating copy does not touch original");

        /* NSCoding round-trip */
        NSData *d = [NSKeyedArchiver archivedDataWithRootObject:p requiringSecureCoding:NO error:NULL];
        NSKeyedUnarchiver *ua = [[NSKeyedUnarchiver alloc] initForReadingFromData:d error:NULL];
        ua.requiresSecureCoding = NO;
        NSPDFInfo *u = [ua decodeObjectForKey:@"root"];
        CHECK(u && u.tagNames.count == 2 && u.orientation == NSPaperOrientationLandscape
              && u.paperSize.height == 792 && !u.isFileExtensionHidden
              && u.attributes.count == 1, "coding round-trip");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
