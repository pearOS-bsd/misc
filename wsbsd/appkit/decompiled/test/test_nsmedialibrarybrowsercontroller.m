/* test_nsmedialibrarybrowsercontroller.m */
#import "../src/NSMediaLibraryBrowserController.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSMediaLibraryBrowserController *c = [NSMediaLibraryBrowserController sharedMediaLibraryBrowserController];
        CHECK(c != nil, "shared instance exists");
        CHECK(c == [NSMediaLibraryBrowserController sharedMediaLibraryBrowserController], "singleton stable");

        /* measured defaults */
        CHECK(!c.isVisible, "not visible default");
        CHECK(CGRectEqualToRect(c.frame, CGRectZero), "frame zero default");
        CHECK(c.mediaLibraries == 0, "mediaLibraries 0 default");

        /* option values */
        CHECK(NSMediaLibraryAudio == 1 && NSMediaLibraryImage == 2 && NSMediaLibraryMovie == 4, "NSMediaLibrary option bits");

        /* togglePanel flips visibility */
        [c togglePanel:nil];
        CHECK(c.isVisible, "togglePanel shows");
        [c togglePanel:nil];
        CHECK(!c.isVisible, "togglePanel hides");

        /* setters */
        c.visible = YES; CHECK(c.isVisible, "visible set");
        c.frame = CGRectMake(10,20,300,400); CHECK(c.frame.size.width == 300, "frame set");
        c.mediaLibraries = NSMediaLibraryImage | NSMediaLibraryMovie;
        CHECK(c.mediaLibraries == (NSMediaLibraryImage | NSMediaLibraryMovie), "mediaLibraries mask set");

        /* reset for cleanliness */
        c.visible = NO;
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
