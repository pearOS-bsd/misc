/* test_nspressureconfiguration.m — NSPressureConfiguration. */
#import "../src/NSPressureConfiguration.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSPressureConfiguration *d = [[NSPressureConfiguration alloc] init];
        CHECK(d.pressureBehavior == NSPressureBehaviorPrimaryDefault, "plain init -> primary default");

        NSPressureConfiguration *dc = [[NSPressureConfiguration alloc] initWithPressureBehavior:NSPressureBehaviorPrimaryDeepClick];
        CHECK(dc.pressureBehavior == NSPressureBehaviorPrimaryDeepClick, "deep-click behavior stored");

        NSPressureConfiguration *acc = [[NSPressureConfiguration alloc] initWithPressureBehavior:NSPressureBehaviorPrimaryAccelerator];
        CHECK(acc.pressureBehavior == NSPressureBehaviorPrimaryAccelerator, "accelerator behavior stored");

        /* set is a no-op in the core, must not crash */
        [dc set];
        CHECK(1, "set does not crash");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
