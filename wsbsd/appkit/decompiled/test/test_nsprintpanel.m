/* test_nsprintpanel.m */
#import "../src/NSPrintPanel.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSPrintPanel *p = [NSPrintPanel printPanel];

        /* measured defaults */
        CHECK(p.options == (NSPrintPanelShowsCopies | NSPrintPanelShowsPageRange), "options = Copies|PageRange (3) default");
        CHECK(p.jobStyleHint == nil, "jobStyleHint nil default");
        CHECK(p.helpAnchor == nil, "helpAnchor nil default");
        CHECK(p.accessoryControllers.count == 0, "no accessory controllers default");
        CHECK(p.printInfo == nil, "printInfo nil outside a run");

        /* option bits */
        CHECK(NSPrintPanelShowsCopies == 1 && NSPrintPanelShowsPageRange == 2 && NSPrintPanelShowsPreview == (1<<17), "option bits");

        /* accessory controllers */
        id acc = [NSObject new];
        [p addAccessoryController:acc];
        CHECK(p.accessoryControllers.count == 1 && p.accessoryControllers[0] == acc, "accessory added");
        [p addAccessoryController:acc];
        CHECK(p.accessoryControllers.count == 1, "duplicate accessory deduped");
        [p removeAccessoryController:acc];
        CHECK(p.accessoryControllers.count == 0, "accessory removed");

        /* setters */
        p.options = NSPrintPanelShowsPreview | NSPrintPanelShowsScaling;
        CHECK(p.options == (NSPrintPanelShowsPreview | NSPrintPanelShowsScaling), "options set");
        p.jobStyleHint = @"photo"; CHECK([p.jobStyleHint isEqual:@"photo"], "jobStyleHint set");
        p.defaultButtonTitle = @"Export"; CHECK([p.defaultButtonTitle isEqual:@"Export"], "defaultButtonTitle set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
