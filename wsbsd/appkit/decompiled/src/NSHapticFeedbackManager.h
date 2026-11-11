/*
 * NSHapticFeedbackManager.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSHapticFeedbackManager and its NSHapticFeedbackPerformer protocol.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSHapticFeedbackManager_interface.txt.
 *
 * +defaultPerformer vends the object that performs trackpad haptics (on hardware
 * an NSTrackpadHapticFeedbackPerformer). This core provides a default performer
 * and the pattern/performance-time enums; the actual haptic actuation is
 * TODO(stage2) — there is no haptic device in the build environment.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSHapticFeedbackPattern) {
    NSHapticFeedbackPatternGeneric     = 0,
    NSHapticFeedbackPatternAlignment   = 1,
    NSHapticFeedbackPatternLevelChange = 2,
};

typedef NS_ENUM(NSInteger, NSHapticFeedbackPerformanceTime) {
    NSHapticFeedbackPerformanceTimeDefault       = 0,
    NSHapticFeedbackPerformanceTimeNow           = 1,
    NSHapticFeedbackPerformanceTimeDrawCompleted = 2,
};

@protocol NSHapticFeedbackPerformer <NSObject>
- (void)performFeedbackPattern:(NSHapticFeedbackPattern)pattern performanceTime:(NSHapticFeedbackPerformanceTime)performanceTime;
@end

@interface NSHapticFeedbackManager : NSObject
@property (class, readonly, strong) id<NSHapticFeedbackPerformer> defaultPerformer;
@end

NS_ASSUME_NONNULL_END
