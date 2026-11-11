/* test_nsuserdefaultscontroller.m — behaviour checks for NSUserDefaultsController core */
#import "../src/NSUserDefaultsController.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        [ud removeObjectForKey:@"tk1"];
        [ud removeObjectForKey:@"tk2"];
        [ud removeObjectForKey:@"tk3"];

        /* shared singleton */
        NSUserDefaultsController *s = [NSUserDefaultsController sharedUserDefaultsController];
        CHECK(s == [NSUserDefaultsController sharedUserDefaultsController], "shared is a singleton");
        CHECK(s.appliesImmediately, "shared appliesImmediately YES");
        CHECK(s.defaults == ud, "defaults is standardUserDefaults");
        CHECK([s isKindOfClass:[NSController class]], "is an NSController");

        /* nil defaults -> standard; initialValues fallback */
        NSUserDefaultsController *c = [[NSUserDefaultsController alloc] initWithDefaults:nil
                                                                           initialValues:@{@"tk1": @"initial"}];
        CHECK(c.defaults == ud, "nil defaults resolves to standard");
        CHECK(c.appliesImmediately, "default appliesImmediately YES");
        CHECK([[c.values valueForKey:@"tk1"] isEqual:@"initial"], "values falls back to initialValues");

        /* immediate write hits defaults, no unapplied changes */
        [c.values setValue:@"applied" forKey:@"tk2"];
        CHECK([[ud objectForKey:@"tk2"] isEqual:@"applied"], "immediate write reaches defaults");
        CHECK(!c.hasUnappliedChanges, "no unapplied changes in immediate mode");
        CHECK([[c.values valueForKey:@"tk2"] isEqual:@"applied"], "values reads stored default over initial");

        /* deferred mode buffers */
        c.appliesImmediately = NO;
        [c.values setValue:@"buffered" forKey:@"tk3"];
        CHECK([ud objectForKey:@"tk3"] == nil, "deferred write does not touch defaults");
        CHECK(c.hasUnappliedChanges, "hasUnappliedChanges YES after deferred write");
        CHECK([[c.values valueForKey:@"tk3"] isEqual:@"buffered"], "values reads buffered value");

        /* save flushes buffer to defaults */
        [c save:nil];
        CHECK([[ud objectForKey:@"tk3"] isEqual:@"buffered"], "save flushes buffer to defaults");
        CHECK(!c.hasUnappliedChanges, "no unapplied changes after save");

        /* deferred write then revert discards */
        [c.values setValue:@"temp" forKey:@"tk3"];
        CHECK(c.hasUnappliedChanges, "unapplied after new deferred write");
        [c revert:nil];
        CHECK(!c.hasUnappliedChanges, "revert discards buffer");
        CHECK([[c.values valueForKey:@"tk3"] isEqual:@"buffered"], "values back to last saved value after revert");

        /* turning appliesImmediately back on flushes */
        [c.values setValue:@"pending" forKey:@"tk2"];
        c.appliesImmediately = YES;
        CHECK([[ud objectForKey:@"tk2"] isEqual:@"pending"], "re-enabling appliesImmediately flushes buffer");

        /* revertToInitialValues restores initial */
        NSUserDefaultsController *c2 = [[NSUserDefaultsController alloc] initWithDefaults:nil
                                                                           initialValues:@{@"tk1": @"orig"}];
        [c2.values setValue:@"changed" forKey:@"tk1"];
        [c2 revertToInitialValues:nil];
        CHECK([[c2.values valueForKey:@"tk1"] isEqual:@"orig"], "revertToInitialValues restores initial");

        /* cleanup */
        [ud removeObjectForKey:@"tk1"];
        [ud removeObjectForKey:@"tk2"];
        [ud removeObjectForKey:@"tk3"];
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
