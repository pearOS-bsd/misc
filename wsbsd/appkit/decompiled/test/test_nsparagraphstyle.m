/* test_nsparagraphstyle.m — NSParagraphStyle / NSMutableParagraphStyle. */
#import "../src/NSParagraphStyle.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSParagraphStyle *def = [NSParagraphStyle defaultParagraphStyle];
        CHECK(def != nil, "defaultParagraphStyle non-nil");
        CHECK([NSParagraphStyle defaultParagraphStyle] == def, "default is a cached singleton");
        CHECK(def.alignment == NSTextAlignmentNatural, "default alignment is Natural");
        CHECK(def.lineBreakMode == NSLineBreakByWordWrapping, "default lineBreakMode is WordWrapping");
        CHECK(def.baseWritingDirection == NSParagraphWritingDirectionNatural, "default direction Natural");
        CHECK(def.lineSpacing == 0.0 && def.firstLineHeadIndent == 0.0, "default metrics zero");

        /* mutate */
        NSMutableParagraphStyle *m = [[NSMutableParagraphStyle alloc] init];
        m.alignment = NSTextAlignmentCenter;
        m.lineBreakMode = NSLineBreakByTruncatingTail;
        m.lineSpacing = 4.0;
        m.firstLineHeadIndent = 12.0;
        m.headIndent = 8.0;
        m.lineHeightMultiple = 1.5;
        m.hyphenationFactor = 0.9f;
        m.tabStops = @[ @1, @2, @3 ];
        CHECK(m.alignment == NSTextAlignmentCenter, "mutable alignment set");
        CHECK(m.lineBreakMode == NSLineBreakByTruncatingTail, "mutable lineBreakMode set");
        CHECK(m.lineSpacing == 4.0, "mutable lineSpacing set");
        CHECK(m.firstLineHeadIndent == 12.0, "mutable firstLineHeadIndent set");
        CHECK(m.lineHeightMultiple == 1.5, "mutable lineHeightMultiple set");
        CHECK(m.hyphenationFactor == 0.9f, "mutable hyphenationFactor set");
        CHECK(m.tabStops.count == 3, "mutable tabStops set");

        /* mutableCopy of default, then diverge */
        NSMutableParagraphStyle *mc = [def mutableCopy];
        CHECK([mc isKindOfClass:[NSMutableParagraphStyle class]], "mutableCopy is mutable");
        mc.alignment = NSTextAlignmentRight;
        CHECK(def.alignment == NSTextAlignmentNatural, "original default unchanged after mutableCopy edit");

        /* immutable copy of a mutable snapshots values */
        NSParagraphStyle *frozen = [m copy];
        CHECK(frozen.alignment == NSTextAlignmentCenter && frozen.lineSpacing == 4.0,
              "copy snapshots values");
        CHECK(![frozen isKindOfClass:[NSMutableParagraphStyle class]], "copy is immutable base");

        /* setParagraphStyle: bulk-copies */
        NSMutableParagraphStyle *dst = [[NSMutableParagraphStyle alloc] init];
        [dst setParagraphStyle:m];
        CHECK(dst.alignment == NSTextAlignmentCenter && dst.headIndent == 8.0 && dst.tabStops.count == 3,
              "setParagraphStyle: copies all fields");

        /* equality */
        NSMutableParagraphStyle *a = [[NSMutableParagraphStyle alloc] init];
        NSMutableParagraphStyle *b = [[NSMutableParagraphStyle alloc] init];
        CHECK([a isEqual:b], "two fresh paragraph styles are equal");
        b.lineSpacing = 1.0;
        CHECK(![a isEqual:b], "differing lineSpacing breaks equality");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
