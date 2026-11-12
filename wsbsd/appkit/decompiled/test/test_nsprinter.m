/* test_nsprinter.m */
#import "../src/NSPrinter.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* registry is CUPS-backed = stage2 (empty here) */
        CHECK([NSPrinter printerNames].count == 0, "printerNames empty (stage2 registry)");
        CHECK([NSPrinter printerTypes].count == 0, "printerTypes empty (stage2)");

        /* build one from a name (BSD-port core) */
        NSPrinter *p = [NSPrinter printerWithName:@"Office-LaserJet"];
        CHECK(p != nil, "printerWithName builds a printer");
        CHECK([p.name isEqual:@"Office-LaserJet"], "name stored");
        CHECK([p.type isEqual:@"Office-LaserJet"], "type stored");
        CHECK(p.languageLevel == 2, "languageLevel default 2");
        CHECK(p.deviceDescription.count == 0, "deviceDescription empty (stage2)");

        /* empty name rejected */
        CHECK([NSPrinter printerWithName:@""] == nil, "empty name -> nil");

        /* paper sizes */
        CGSize a4 = [p pageSizeForPaper:@"A4"];
        CHECK(a4.width == 595 && a4.height == 842, "A4 page size");
        CGSize letter = [p pageSizeForPaper:@"Letter"];
        CHECK(letter.width == 612 && letter.height == 792, "US Letter fallback");

        /* NSCopying + NSCoding */
        NSPrinter *c = [p copy];
        CHECK([c.name isEqual:@"Office-LaserJet"] && c.languageLevel == 2, "copy preserves name + level");
        NSData *d = [NSKeyedArchiver archivedDataWithRootObject:p requiringSecureCoding:YES error:NULL];
        NSPrinter *u = [NSKeyedUnarchiver unarchivedObjectOfClass:[NSPrinter class] fromData:d error:NULL];
        CHECK(u && [u.name isEqual:@"Office-LaserJet"], "secure coding round-trip");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
