/*
 * NSAnimation.m — behavioral-1:1 core. See NSAnimation.h for interface evidence
 * and the stage2 boundary (real CADisplayLink/NSTimer run loop lives there).
 */

#import "NSAnimation.h"

static float NSAnimationClampProgress(float p)
{
    if (p < 0.0f) return 0.0f;
    if (p > 1.0f) return 1.0f;
    return p;
}

@implementation NSAnimation

- (instancetype)initWithDuration:(NSTimeInterval)duration
                  animationCurve:(NSAnimationCurve)animationCurve
{
    self = [super init];
    if (self) {
        _duration = duration;
        _animationCurve = animationCurve;
        _animationBlockingMode = NSAnimationBlocking;
        _framesPerSecond = 60.0f;
        _currentProgress = 0.0f;
        _progressMarks = [[NSMutableArray alloc] init];
        _startProgressTrigger = 0.0f;
        _stopProgressTrigger = 0.0f;
        _animating = NO;
    }
    return self;
}

- (instancetype)init
{
    /* Plain -init is not the designated initializer; it defaults to a
     * zero-duration ease-in-out animation (the designated initializer's path). */
    return [self initWithDuration:0.0 animationCurve:NSAnimationEaseInOut];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    /* TODO(stage2): decode duration/curve/blockingMode/progressMarks. */
    return [self initWithDuration:0.0 animationCurve:NSAnimationEaseInOut];
}

- (void)encodeWithCoder:(NSCoder *)coder
{
    /* TODO(stage2): archive the value model. */
}

/* --- value model --- */

- (NSTimeInterval)duration { return _duration; }
- (void)setDuration:(NSTimeInterval)duration { _duration = duration; }

- (NSAnimationProgress)currentProgress { return _currentProgress; }
- (void)setCurrentProgress:(NSAnimationProgress)p
{
    _currentProgress = NSAnimationClampProgress(p);
    /* TODO(stage2): setting progress mid-run fires progress-mark/handler. */
}

- (NSAnimationCurve)animationCurve { return _animationCurve; }
- (void)setAnimationCurve:(NSAnimationCurve)c { _animationCurve = c; }

- (NSAnimationBlockingMode)animationBlockingMode { return _animationBlockingMode; }
- (void)setAnimationBlockingMode:(NSAnimationBlockingMode)m { _animationBlockingMode = m; }

- (float)frameRate { return _framesPerSecond; }
- (void)setFrameRate:(float)fps { _framesPerSecond = fps; }

- (id<NSAnimationDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSAnimationDelegate>)d { _delegate = d; }

- (float)currentValue
{
    /* If the delegate supplies values it wins (documented override point). */
    if ([_delegate respondsToSelector:@selector(animation:valueForProgress:)])
        return [_delegate animation:self valueForProgress:_currentProgress];

    float p = _currentProgress;
    switch (_animationCurve) {
        case NSAnimationLinear:  return p;
        case NSAnimationEaseIn:  return p * p;                 /* stage2: exact spline */
        case NSAnimationEaseOut: return p * (2.0f - p);        /* stage2: exact spline */
        case NSAnimationEaseInOut:
        default:                 return p * p * (3.0f - 2.0f * p); /* smoothstep; stage2 */
    }
}

/* --- progress marks (kept sorted & unique) --- */

- (NSArray<NSNumber *> *)progressMarks { return [_progressMarks copy]; }

- (void)setProgressMarks:(NSArray<NSNumber *> *)marks
{
    [_progressMarks removeAllObjects];
    for (NSNumber *n in marks)
        [self addProgressMark:n.floatValue];
}

- (void)addProgressMark:(NSAnimationProgress)mark
{
    mark = NSAnimationClampProgress(mark);
    for (NSNumber *n in _progressMarks)
        if (n.floatValue == mark) return;              /* dedup */
    NSUInteger i = 0;
    for (; i < _progressMarks.count; i++)
        if ([_progressMarks[i] floatValue] > mark) break;
    [_progressMarks insertObject:@(mark) atIndex:i];   /* keep sorted */
}

- (void)removeProgressMark:(NSAnimationProgress)mark
{
    NSUInteger idx = [_progressMarks indexOfObjectPassingTest:^BOOL(NSNumber *n, NSUInteger i, BOOL *stop) {
        return n.floatValue == mark;
    }];
    if (idx != NSNotFound) [_progressMarks removeObjectAtIndex:idx];
}

/* --- linked animations --- */

- (void)startWhenAnimation:(NSAnimation *)animation reachesProgress:(NSAnimationProgress)startProgress
{
    _startAnimation = animation;
    _startProgressTrigger = startProgress;
    /* TODO(stage2): register as a progress-mark observer on `animation`. */
}

- (void)stopWhenAnimation:(NSAnimation *)animation reachesProgress:(NSAnimationProgress)stopProgress
{
    _stopAnimation = animation;
    _stopProgressTrigger = stopProgress;
}

- (void)clearStartAnimation { _startAnimation = nil; _startProgressTrigger = 0.0f; }
- (void)clearStopAnimation  { _stopAnimation  = nil; _stopProgressTrigger  = 0.0f; }

/* --- run control (stage2 timeline) --- */

- (BOOL)isAnimating { return _animating; }

- (void)startAnimation
{
    if (_animating) return;
    if ([_delegate respondsToSelector:@selector(animationShouldStart:)])
        if (![_delegate animationShouldStart:self]) return;
    _animating = YES;
    /* TODO(stage2): create the CADisplayLink / fallback timer and drive
     * _currentProgress from _startTime over _duration honouring
     * animationBlockingMode and runLoopModesForAnimating. */
}

- (void)stopAnimation
{
    if (!_animating) return;
    _animating = NO;
    /* TODO(stage2): tear down the timer. */
    if ([_delegate respondsToSelector:@selector(animationDidStop:)])
        [_delegate animationDidStop:self];
}

- (NSArray<NSRunLoopMode> *)runLoopModesForAnimating { return @[]; }

/* --- copying --- */

- (id)copyWithZone:(NSZone *)zone
{
    NSAnimation *c = [[[self class] alloc] initWithDuration:_duration animationCurve:_animationCurve];
    c->_currentProgress = _currentProgress;
    c->_framesPerSecond = _framesPerSecond;
    c->_animationBlockingMode = _animationBlockingMode;
    c->_delegate = _delegate;
    c->_progressMarks = [_progressMarks mutableCopy];
    c->_startAnimation = _startAnimation;
    c->_startProgressTrigger = _startProgressTrigger;
    c->_stopAnimation = _stopAnimation;
    c->_stopProgressTrigger = _stopProgressTrigger;
    return c;
}

@end
