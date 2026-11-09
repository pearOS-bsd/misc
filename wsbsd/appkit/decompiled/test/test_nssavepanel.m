/* test_nssavepanel.m — NSSavePanel (: NSPanel) property core. */
#import "../src/NSSavePanel.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSSavePanel *sp = [[NSSavePanel alloc] init];
        CHECK([sp isKindOfClass:[NSPanel class]], "NSSavePanel is an NSPanel");
        CHECK([sp isKindOfClass:[NSWindow class]], "...and an NSWindow");

        CHECK([sp.nameFieldStringValue isEqualToString:@""], "nameFieldStringValue empty by default");
        CHECK(sp.canCreateDirectories == YES, "canCreateDirectories defaults YES");

        sp.nameFieldStringValue = @"Untitled.txt";
        CHECK([sp.nameFieldStringValue isEqualToString:@"Untitled.txt"], "nameFieldStringValue round-trips");

        NSURL *dir = [NSURL fileURLWithPath:@"/Users/x/Documents"];
        sp.directoryURL = dir;
        CHECK([sp.directoryURL isEqual:dir], "directoryURL round-trips");

        sp.canCreateDirectories = NO;
        CHECK(!sp.canCreateDirectories, "canCreateDirectories round-trips");
        sp.showsHiddenFiles = YES;
        CHECK(sp.showsHiddenFiles, "showsHiddenFiles round-trips");
        sp.allowsOtherFileTypes = YES;
        CHECK(sp.allowsOtherFileTypes, "allowsOtherFileTypes round-trips");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
