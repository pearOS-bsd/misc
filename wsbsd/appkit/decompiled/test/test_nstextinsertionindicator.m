/* test_nstextinsertionindicator.m — behaviour checks for NSTextInsertionIndicator core */
#import "../src/NSTextInsertionIndicator.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSTextInsertionIndicator *v = [[NSTextInsertionIndicator alloc] initWithFrame:NSMakeRect(0, 0, 2, 16)];
        CHECK([v isKindOfClass:[NSView class]], "is an NSView");

        /* measured defaults */
        CHECK(v.displayMode == NSTextInsertionIndicatorDisplayModeAutomatic, "displayMode default Automatic");
        CHECK(v.automaticModeOptions == NSTextInsertionIndicatorAutomaticModeOptionsWhileTracking, "automaticModeOptions default WhileTracking(1)");
        CHECK(v.color == nil, "color nil in core (semantic default stage2)");

        /* enum values */
        CHECK(NSTextInsertionIndicatorDisplayModeAutomatic == 0
              && NSTextInsertionIndicatorDisplayModeHidden == 1
              && NSTextInsertionIndicatorDisplayModeVisible == 2, "display-mode enum values");
        CHECK(NSTextInsertionIndicatorAutomaticModeOptionsWhileTracking == 1
              && NSTextInsertionIndicatorAutomaticModeOptionsShowEffectsView == 2, "automatic-mode option bits");

        /* setters round-trip (documented contract) */
        v.displayMode = NSTextInsertionIndicatorDisplayModeVisible;
        CHECK(v.displayMode == NSTextInsertionIndicatorDisplayModeVisible, "displayMode set/get");
        v.displayMode = NSTextInsertionIndicatorDisplayModeHidden;
        CHECK(v.displayMode == NSTextInsertionIndicatorDisplayModeHidden, "displayMode Hidden");

        v.automaticModeOptions = NSTextInsertionIndicatorAutomaticModeOptionsWhileTracking
                               | NSTextInsertionIndicatorAutomaticModeOptionsShowEffectsView;
        CHECK(v.automaticModeOptions == 3, "automaticModeOptions bitmask set");

        /* effectsViewInserter block stored (copied) */
        id block = ^(id a) { (void)a; };
        v.effectsViewInserter = block;
        CHECK(v.effectsViewInserter != nil, "effectsViewInserter stored");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
