/* test_nspagelayout.m */
#import "../src/NSPageLayout.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSPageLayout *p = [NSPageLayout pageLayout];
        CHECK(p != nil, "pageLayout factory");
        CHECK(p.accessoryControllers.count == 0, "no accessory controllers default");
        CHECK(p.printInfo == nil, "printInfo nil outside a run");

        id acc = [NSObject new];
        [p addAccessoryController:acc];
        CHECK(p.accessoryControllers.count == 1 && p.accessoryControllers[0] == acc, "accessory added");
        [p addAccessoryController:acc];
        CHECK(p.accessoryControllers.count == 1, "duplicate accessory deduped");
        [p removeAccessoryController:acc];
        CHECK(p.accessoryControllers.count == 0, "accessory removed");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
