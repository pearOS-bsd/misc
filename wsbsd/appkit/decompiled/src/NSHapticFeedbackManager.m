/*
 * NSHapticFeedbackManager.m — behavioral-1:1 core. See the header.
 */

#import "NSHapticFeedbackManager.h"

/* The concrete default performer. On hardware this is backed by the trackpad
 * actuator; here it records the last request so callers/tests can observe it,
 * and the physical actuation is stage2. */
@interface _NSDefaultHapticFeedbackPerformer : NSObject <NSHapticFeedbackPerformer>
@property (readonly) NSHapticFeedbackPattern lastPattern;
@property (readonly) NSHapticFeedbackPerformanceTime lastPerformanceTime;
@property (readonly) NSInteger performCount;
@end

@implementation _NSDefaultHapticFeedbackPerformer
- (void)performFeedbackPattern:(NSHapticFeedbackPattern)pattern performanceTime:(NSHapticFeedbackPerformanceTime)performanceTime
{
    _lastPattern = pattern;
    _lastPerformanceTime = performanceTime;
    _performCount++;
    /* TODO(stage2): drive the real trackpad haptic actuator. */
}
@end

@implementation NSHapticFeedbackManager

+ (id<NSHapticFeedbackPerformer>)defaultPerformer
{
    static id<NSHapticFeedbackPerformer> performer;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ performer = [[_NSDefaultHapticFeedbackPerformer alloc] init]; });
    return performer;
}

@end
