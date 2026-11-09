/* test_nstouchbaritem.m — NSTouchBarItem base. */
#import "../src/NSTouchBarItem.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTouchBarItem *item = [[NSTouchBarItem alloc] initWithIdentifier:@"com.app.play"];
        CHECK([item.identifier isEqualToString:@"com.app.play"], "identifier from init");
        CHECK(item.visibilityPriority == NSTouchBarItemPriorityNormal, "default visibility priority Normal (0)");
        CHECK(item.view == nil, "base view is nil");
        CHECK(item.viewController == nil, "base viewController is nil");
        CHECK(item.customizationLabel == nil, "base customizationLabel is nil");
        CHECK(!item.isVisible, "base not visible");

        item.visibilityPriority = NSTouchBarItemPriorityHigh;
        CHECK(item.visibilityPriority == 1000, "visibility priority High = 1000");
        item.visibilityPriority = NSTouchBarItemPriorityLow;
        CHECK(item.visibilityPriority == -1000, "visibility priority Low = -1000");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
