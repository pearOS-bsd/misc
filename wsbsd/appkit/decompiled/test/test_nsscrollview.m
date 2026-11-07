/* test_nsscrollview.m — NSScrollView + NSClipView: documentView wiring, borderType. */
#import "../src/NSScrollView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSScrollView *sv = [[NSScrollView alloc] initWithFrame:CGRectMake(0, 0, 200, 150)];
        CHECK([sv.contentView isKindOfClass:[NSClipView class]], "contentView is an NSClipView");
        CHECK(sv.contentView.superview == sv, "clip view is a subview of the scroll view");
        CHECK(sv.documentView == nil, "no document view yet");

        NSView *doc = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 500, 800)];
        sv.documentView = doc;
        CHECK(sv.documentView == doc, "documentView delegates to the clip view");
        CHECK(sv.contentView.documentView == doc, "clip view holds the document view");
        CHECK(doc.superview == sv.contentView, "document view is a subview of the clip view");

        /* replacing the document view detaches the old one */
        NSView *doc2 = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        sv.documentView = doc2;
        CHECK(sv.documentView == doc2, "document view replaced");
        CHECK(doc.superview == nil, "old document view detached");

        /* borderType packed in _sFlags */
        sv.borderType = NSBezelBorder;
        CHECK(sv.borderType == NSBezelBorder, "borderType round-trips");
        sv.borderType = NSGrooveBorder;
        CHECK(sv.borderType == NSGrooveBorder, "borderType updates");

        sv.hasVerticalScroller = YES;
        sv.hasHorizontalScroller = YES;
        CHECK(sv.hasVerticalScroller && sv.hasHorizontalScroller, "scroller flags round-trip");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
