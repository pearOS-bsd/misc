/* test_nshapticfeedbackmanager.m — behaviour checks for NSHapticFeedbackManager core */
#import "../src/NSHapticFeedbackManager.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface _NSDefaultHapticFeedbackPerformer : NSObject
@property (readonly) NSHapticFeedbackPattern lastPattern;
@property (readonly) NSInteger performCount;
@end

int main(void) {
    @autoreleasepool {
        id<NSHapticFeedbackPerformer> p = NSHapticFeedbackManager.defaultPerformer;
        CHECK(p != nil, "defaultPerformer non-nil");
        CHECK(p == NSHapticFeedbackManager.defaultPerformer, "defaultPerformer is a singleton");
        CHECK([p conformsToProtocol:@protocol(NSHapticFeedbackPerformer)], "conforms to NSHapticFeedbackPerformer");

        /* enum values */
        CHECK(NSHapticFeedbackPatternGeneric == 0 && NSHapticFeedbackPatternAlignment == 1 && NSHapticFeedbackPatternLevelChange == 2, "pattern enum");
        CHECK(NSHapticFeedbackPerformanceTimeDefault == 0 && NSHapticFeedbackPerformanceTimeNow == 1 && NSHapticFeedbackPerformanceTimeDrawCompleted == 2, "performance-time enum");

        /* perform is a safe no-op (records the request in the core) */
        [p performFeedbackPattern:NSHapticFeedbackPatternAlignment performanceTime:NSHapticFeedbackPerformanceTimeNow];
        _NSDefaultHapticFeedbackPerformer *dp = (id)p;
        CHECK(dp.lastPattern == NSHapticFeedbackPatternAlignment, "records last pattern");
        CHECK(dp.performCount == 1, "records perform count");
        [p performFeedbackPattern:NSHapticFeedbackPatternLevelChange performanceTime:NSHapticFeedbackPerformanceTimeDefault];
        CHECK(dp.performCount == 2 && dp.lastPattern == NSHapticFeedbackPatternLevelChange, "second perform recorded");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
