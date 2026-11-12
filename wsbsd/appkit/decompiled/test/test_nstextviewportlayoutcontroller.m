/* test_nstextviewportlayoutcontroller.m */
#import "../src/NSTextViewportLayoutController.h"
#import "../src/NSTextLayoutManager.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSTextLayoutManager *lm = [[NSTextLayoutManager alloc] init];
        NSTextViewportLayoutController *v = [[NSTextViewportLayoutController alloc] initWithTextLayoutManager:lm];

        /* measured defaults */
        CHECK(v.textLayoutManager == lm, "layout manager stored (weak)");
        CHECK(v.delegate == nil, "delegate nil default");
        CHECK(CGRectEqualToRect(v.viewportBounds, CGRectZero), "viewportBounds zero (pre-layout)");
        CHECK(v.viewportRange == nil, "viewportRange nil (pre-layout)");

        /* delegate settable */
        id d = [NSObject new];
        v.delegate = (id)d;
        CHECK((id)v.delegate == d, "delegate set (weak)");

        /* layout cycle is stage2: no-ops, no crash, state unchanged */
        [v layoutViewport];
        [v adjustViewportByVerticalOffset:40];
        [v relocateViewportToTextLocation:nil];
        CHECK(CGRectEqualToRect(v.viewportBounds, CGRectZero), "viewport bounds still zero (stage2)");
        CHECK(v.viewportRange == nil, "viewport range still nil (stage2)");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
