/* test_nstextcontainer.m — NSTextContainer geometry + flags. */
#import "../src/NSTextContainer.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTextContainer *c = [[NSTextContainer alloc] initWithSize:CGSizeMake(320, 480)];
        CHECK(c.size.width == 320 && c.size.height == 480, "size from init");
        CHECK(c.lineFragmentPadding == 5.0, "default lineFragmentPadding 5.0");
        CHECK(c.maximumNumberOfLines == 0, "default maxLines 0 (unlimited)");
        CHECK(c.lineBreakMode == NSLineBreakByWordWrapping, "default lineBreakMode word wrapping");
        CHECK(!c.widthTracksTextView && !c.heightTracksTextView, "tracking off by default");
        CHECK(c.exclusionPaths.count == 0, "no exclusion paths by default");

        c.size = CGSizeMake(100, 200);
        c.lineFragmentPadding = 0.0;
        c.maximumNumberOfLines = 3;
        c.lineBreakMode = NSLineBreakByTruncatingTail;
        c.widthTracksTextView = YES;
        c.heightTracksTextView = YES;
        c.exclusionPaths = @[ @"p1", @"p2" ];
        CHECK(c.size.width == 100, "size settable");
        CHECK(c.lineFragmentPadding == 0.0, "padding settable");
        CHECK(c.maximumNumberOfLines == 3, "maxLines settable");
        CHECK(c.lineBreakMode == NSLineBreakByTruncatingTail, "lineBreakMode settable");
        CHECK(c.widthTracksTextView && c.heightTracksTextView, "tracking flags settable");
        CHECK(c.exclusionPaths.count == 2, "exclusion paths settable");

        /* plain init */
        NSTextContainer *z = [[NSTextContainer alloc] init];
        CHECK(z.size.width == 0 && z.lineFragmentPadding == 5.0, "plain init zero size, default padding");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
