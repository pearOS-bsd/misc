/* test_nsvisualeffectview.m — NSVisualEffectView: material/blendingMode/state/emphasized. */
#import "../src/NSVisualEffectView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSVisualEffectView *v = [[NSVisualEffectView alloc] initWithFrame:CGRectMake(0,0,100,100)];

        v.material = NSVisualEffectMaterialSidebar;
        CHECK(v.material == NSVisualEffectMaterialSidebar, "material round-trips");
        v.material = NSVisualEffectMaterialHUDWindow;
        CHECK(v.material == NSVisualEffectMaterialHUDWindow, "material updates");

        v.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        CHECK(v.blendingMode == NSVisualEffectBlendingModeWithinWindow, "blendingMode round-trips");

        v.state = NSVisualEffectStateActive;
        CHECK(v.state == NSVisualEffectStateActive, "state round-trips");

        CHECK(v.isEmphasized == NO, "emphasized defaults NO");
        v.emphasized = YES;
        CHECK(v.isEmphasized == YES, "emphasized round-trips");
        /* emphasized (a bit in its own byte) independent of material/state */
        CHECK(v.material == NSVisualEffectMaterialHUDWindow && v.state == NSVisualEffectStateActive,
              "emphasized does not disturb material/state");

        CHECK([v isKindOfClass:[NSView class]], "NSVisualEffectView is an NSView");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
