/* test_nscolorpanel.m */
#import "../src/NSColorPanel.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface Catcher : NSObject
@property NSInteger hits;
- (void)changed:(id)sender;
@end
@implementation Catcher
- (void)changed:(id)sender { self.hits++; }
@end

int main(void) {
    @autoreleasepool {
        CHECK(![NSColorPanel sharedColorPanelExists], "panel does not exist before first access");
        NSColorPanel *p = [NSColorPanel sharedColorPanel];
        CHECK(p != nil && p == [NSColorPanel sharedColorPanel], "singleton");
        CHECK([NSColorPanel sharedColorPanelExists], "panel exists after access");
        CHECK([p isKindOfClass:[NSPanel class]], "is-a NSPanel");

        /* measured defaults */
        CHECK(p.mode == NSColorPanelModeWheel, "mode Wheel default");
        CHECK(p.showsAlpha, "showsAlpha YES default");
        CHECK(p.isContinuous, "continuous YES default");

        /* mode enum */
        CHECK(NSColorPanelModeGray == 0 && NSColorPanelModeRGB == 1 && NSColorPanelModeCrayon == 7, "mode enum");

        /* target/action fires on a continuous color change */
        Catcher *cat = [Catcher new];
        [p setTarget:cat];
        [p setAction:@selector(changed:)];
        id col = [NSObject new];
        p.color = (id)col;
        CHECK((id)p.color == col, "color set");
        CHECK(cat.hits == 1, "continuous change fires action");

        /* non-continuous: no action fired */
        p.continuous = NO;
        p.color = (id)[NSObject new];
        CHECK(cat.hits == 1, "non-continuous does not fire action");

        /* setters */
        p.mode = NSColorPanelModeRGB; CHECK(p.mode == NSColorPanelModeRGB, "mode set");
        p.showsAlpha = NO; CHECK(!p.showsAlpha, "showsAlpha set");
        id acc = [NSObject new]; p.accessoryView = (id)acc;
        CHECK((id)p.accessoryView == acc, "accessoryView set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
