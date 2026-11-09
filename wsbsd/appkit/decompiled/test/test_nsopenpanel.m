/* test_nsopenpanel.m — NSOpenPanel (: NSSavePanel : NSPanel). */
#import "../src/NSOpenPanel.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSOpenPanel *op = [[NSOpenPanel alloc] init];
        CHECK([op isKindOfClass:[NSSavePanel class]], "NSOpenPanel is an NSSavePanel");
        CHECK([op isKindOfClass:[NSPanel class]], "...and an NSPanel");

        /* defaults */
        CHECK(op.canChooseFiles == YES, "canChooseFiles default YES");
        CHECK(op.canChooseDirectories == NO, "canChooseDirectories default NO");
        CHECK(op.allowsMultipleSelection == NO, "allowsMultipleSelection default NO");
        CHECK(op.resolvesAliases == YES, "resolvesAliases default YES");

        /* a directory chooser */
        op.canChooseFiles = NO;
        op.canChooseDirectories = YES;
        op.allowsMultipleSelection = YES;
        CHECK(!op.canChooseFiles && op.canChooseDirectories && op.allowsMultipleSelection,
              "directory-chooser config round-trips");

        /* inherits NSSavePanel properties */
        op.directoryURL = [NSURL fileURLWithPath:@"/"];
        CHECK([op.directoryURL.path isEqualToString:@"/"], "inherits directoryURL from NSSavePanel");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
