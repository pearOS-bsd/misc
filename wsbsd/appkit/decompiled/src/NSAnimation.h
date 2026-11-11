/*
 * NSAnimation.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSAnimation.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e,
 * `ipsw dyld macho <dsc> AppKit --objc`) in evidence/-NSAnimation_interface.txt.
 * Real ivars: _duration, _currentProgress, _framesPerSecond, _delegate(weak),
 * _displayLink(CADisplayLink), _startTime, _progressMarks, _startAnimation +
 * _startProgressTrigger, _stopAnimation + _stopProgressTrigger,
 * _scheduledRunLoop, _progressHandler, _nextProgressMark, and a packed _aFlags
 * bitfield carrying delegate-responds caches, animating/blocking,
 * animationCurve (b8) and animationBlockingMode (b2).
 *
 * This core reproduces the observable value model: duration, currentProgress
 * (clamped to [0,1]), frameRate, animationCurve, animationBlockingMode,
 * weak delegate, progressMarks (sorted/unique), currentValue (curve applied to
 * progress), isAnimating, and the linked start/stop-when-animation-reaches
 * wiring. TODO(stage2): the real run loop — CADisplayLink / fallback NSTimer,
 * the blocking/non-blocking/threaded run modes (_runBlocking,
 * _startRunningNonBlocking, _runInNewThread, _advanceTimeWithDisplayLink:),
 * delegate callbacks fired off the timeline, progress-handler dispatch, and
 * NSCoding. The easing spline for the non-linear curves is approximated with a
 * monotonic ease (endpoints exact); the exact Apple curve is stage2.
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef float NSAnimationProgress;

typedef NS_ENUM(NSUInteger, NSAnimationCurve) {
    NSAnimationEaseInOut = 0,
    NSAnimationEaseIn    = 1,
    NSAnimationEaseOut   = 2,
    NSAnimationLinear    = 3,
};

typedef NS_ENUM(NSUInteger, NSAnimationBlockingMode) {
    NSAnimationBlocking            = 0,
    NSAnimationNonblocking         = 1,
    NSAnimationNonblockingThreaded = 2,
};

@protocol NSAnimationDelegate;

@interface NSAnimation : NSObject <NSCopying, NSCoding> {
    NSTimeInterval        _duration;
    NSAnimationProgress   _currentProgress;
    float                 _framesPerSecond;
    __weak id<NSAnimationDelegate> _delegate;
    NSMutableArray       *_progressMarks;
    NSAnimation          *_startAnimation;
    float                 _startProgressTrigger;
    NSAnimation          *_stopAnimation;
    float                 _stopProgressTrigger;
    NSAnimationCurve         _animationCurve;
    NSAnimationBlockingMode  _animationBlockingMode;
    BOOL                  _animating;
}

- (instancetype)initWithDuration:(NSTimeInterval)duration
                  animationCurve:(NSAnimationCurve)animationCurve NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (instancetype)initWithCoder:(NSCoder *)coder;

- (void)startAnimation;
- (void)stopAnimation;
@property (getter=isAnimating, readonly) BOOL animating;

@property NSAnimationProgress currentProgress;
@property NSTimeInterval duration;
@property NSAnimationBlockingMode animationBlockingMode;
@property float frameRate;
@property NSAnimationCurve animationCurve;
@property (readonly) float currentValue;

@property (nullable, weak) id<NSAnimationDelegate> delegate;

@property (nullable, copy) NSArray<NSNumber *> *progressMarks;
- (void)addProgressMark:(NSAnimationProgress)progressMark;
- (void)removeProgressMark:(NSAnimationProgress)progressMark;

- (void)startWhenAnimation:(NSAnimation *)animation reachesProgress:(NSAnimationProgress)startProgress;
- (void)stopWhenAnimation:(NSAnimation *)animation reachesProgress:(NSAnimationProgress)stopProgress;
- (void)clearStartAnimation;
- (void)clearStopAnimation;

@property (readonly, copy) NSArray<NSRunLoopMode> *runLoopModesForAnimating;

@end

@protocol NSAnimationDelegate <NSObject>
@optional
- (BOOL)animationShouldStart:(NSAnimation *)animation;
- (void)animationDidStop:(NSAnimation *)animation;
- (void)animationDidEnd:(NSAnimation *)animation;
- (float)animation:(NSAnimation *)animation valueForProgress:(NSAnimationProgress)progress;
- (void)animation:(NSAnimation *)animation didReachProgressMark:(NSAnimationProgress)progress;
@end

NS_ASSUME_NONNULL_END
