/* test_nsfontpanel.m */
#import "../src/NSFontPanel.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        CHECK(![NSFontPanel sharedFontPanelExists], "panel does not exist before first access");
        NSFontPanel *p = [NSFontPanel sharedFontPanel];
        CHECK(p != nil && p == [NSFontPanel sharedFontPanel], "singleton");
        CHECK([NSFontPanel sharedFontPanelExists], "exists after access");
        CHECK([p isKindOfClass:[NSPanel class]], "is-a NSPanel");

        /* measured defaults */
        CHECK(p.worksWhenModal, "worksWhenModal YES default");
        CHECK(p.isEnabled, "enabled YES default");

        /* setPanelFont:isMultiple: records selection; panelConvertFont: returns input standalone */
        id font = [NSObject new];
        [p setPanelFont:(id)font isMultiple:YES];
        CHECK((id)[p panelConvertFont:(id)font] == font, "panelConvertFont returns input (stage2)");

        /* setters */
        p.worksWhenModal = NO; CHECK(!p.worksWhenModal, "worksWhenModal set");
        p.enabled = NO; CHECK(!p.isEnabled, "enabled set");
        id acc = [NSObject new]; p.accessoryView = (id)acc;
        CHECK((id)p.accessoryView == acc, "accessoryView set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
