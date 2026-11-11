/* test_nspagecontroller.m — behaviour checks for NSPageController page-model core */
#import "../src/NSPageController.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSPageController *p = [[NSPageController alloc] init];
        CHECK([p isKindOfClass:[NSViewController class]], "is an NSViewController");

        /* measured defaults */
        CHECK(p.transitionStyle == NSPageControllerTransitionStyleStackHistory, "transitionStyle default StackHistory(0)");
        CHECK(p.selectedIndex == 0, "selectedIndex default 0");
        CHECK(p.arrangedObjects.count == 0, "arrangedObjects empty");

        /* set arranged objects */
        p.arrangedObjects = @[@"a", @"b", @"c"];
        CHECK(p.arrangedObjects.count == 3 && p.selectedIndex == 0, "arrangedObjects set, selection 0");

        /* navigateForward clamps at count-1 */
        [p navigateForward:nil];
        CHECK(p.selectedIndex == 1, "navigateForward +1");
        [p navigateForward:nil]; [p navigateForward:nil];
        CHECK(p.selectedIndex == 2, "navigateForward clamps at last");

        /* navigateBack clamps at 0 */
        [p navigateBack:nil];
        CHECK(p.selectedIndex == 1, "navigateBack -1");
        p.selectedIndex = 0;
        [p navigateBack:nil];
        CHECK(p.selectedIndex == 0, "navigateBack clamps at 0");

        /* setSelectedIndex out of range raises (measured) */
        BOOL raised = NO;
        @try { p.selectedIndex = 99; } @catch (NSException *e) { raised = [e.name isEqual:NSInternalInconsistencyException]; }
        CHECK(raised, "setSelectedIndex out of range raises");
        CHECK(p.selectedIndex == 0, "selectedIndex unchanged after failed set");

        /* valid setSelectedIndex works */
        p.selectedIndex = 2;
        CHECK(p.selectedIndex == 2, "valid setSelectedIndex");

        /* navigateForwardToObject appends and selects it */
        [p navigateForwardToObject:@"d"];
        CHECK(p.arrangedObjects.count == 4 && p.selectedIndex == 3 && [p.arrangedObjects[3] isEqual:@"d"],
              "navigateForwardToObject appends + selects");

        /* removeForwardNavigableObjects truncates after selection */
        p.selectedIndex = 1;
        [p removeForwardNavigableObjects];
        CHECK(p.arrangedObjects.count == 2, "removeForwardNavigableObjects truncates to selection+1");

        /* transitionStyle round-trip */
        p.transitionStyle = NSPageControllerTransitionStyleHorizontalStrip;
        CHECK(p.transitionStyle == NSPageControllerTransitionStyleHorizontalStrip, "transitionStyle set");

        /* selectedViewController is stage2 nil, completeTransition safe */
        CHECK(p.selectedViewController == nil, "selectedViewController stage2 nil");
        [p completeTransition];
        CHECK(1, "completeTransition safe");

        /* takeSelectedIndexFrom reads integerValue */
        [p setArrangedObjects:@[@1,@2,@3,@4,@5]];
        [p takeSelectedIndexFrom:@3];
        CHECK(p.selectedIndex == 3, "takeSelectedIndexFrom uses integerValue");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
