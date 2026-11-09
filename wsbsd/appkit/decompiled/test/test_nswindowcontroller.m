/* test_nswindowcontroller.m — NSWindowController window/content/document. */
#import "../src/NSWindowController.h"
#import "../src/NSWindow.h"
#import "../src/NSViewController.h"
#import "../src/NSView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSWindow *win = [[NSWindow alloc] initWithContentRect:CGRectMake(0,0,400,300)
                                                    styleMask:0 backing:0 defer:NO];
        NSWindowController *wc = [[NSWindowController alloc] initWithWindow:win];
        CHECK(wc.window == win, "window adopted");
        CHECK(wc.isWindowLoaded, "window loaded when provided");
        CHECK([wc.windowFrameAutosaveName isEqualToString:@""], "autosave name default empty");

        /* no-window controller */
        NSWindowController *empty = [[NSWindowController alloc] init];
        CHECK(!empty.isWindowLoaded, "no window -> not loaded");
        empty.window = win;
        CHECK(empty.isWindowLoaded, "setWindow marks loaded");

        /* document (weak) */
        id doc = [NSObject new];
        wc.document = doc;
        CHECK(wc.document == doc, "document set");

        /* contentViewController installs its view as the window content view */
        NSViewController *vc = [[NSViewController alloc] init];
        NSView *cview = [[NSView alloc] initWithFrame:CGRectMake(0,0,400,300)];
        vc.view = cview;
        wc.contentViewController = vc;
        CHECK(wc.contentViewController == vc, "contentViewController set");
        CHECK(win.contentView == cview, "window contentView driven by the content view controller");

        /* autosave name */
        wc.windowFrameAutosaveName = @"MainWindow";
        CHECK([wc.windowFrameAutosaveName isEqualToString:@"MainWindow"], "autosave name set");

        /* showWindow / close do not crash and toggle visibility */
        [wc showWindow:nil];
        CHECK(win.isVisible, "showWindow makes the window visible");
        [wc close];
        CHECK(!win.isVisible, "close orders the window out");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
