/*
 * NSViewAnimation.m — behavioral-1:1 core. See NSViewAnimation.h.
 */

#import "NSViewAnimation.h"
#import <objc/message.h>

NSViewAnimationKey const NSViewAnimationTargetKey     = @"NSViewAnimationTarget";
NSViewAnimationKey const NSViewAnimationStartFrameKey = @"NSViewAnimationStartFrame";
NSViewAnimationKey const NSViewAnimationEndFrameKey   = @"NSViewAnimationEndFrame";
NSViewAnimationKey const NSViewAnimationEffectKey     = @"NSViewAnimationEffect";

NSViewAnimationEffectName const NSViewAnimationFadeInEffect  = @"fadein";
NSViewAnimationEffectName const NSViewAnimationFadeOutEffect = @"fadeout";

@implementation NSViewAnimation

- (instancetype)initWithViewAnimations:(NSArray<NSDictionary<NSViewAnimationKey, id> *> *)viewAnimations
{
    /* NSViewAnimation's default timeline is a 0.5s ease-in-out. */
    self = [super initWithDuration:0.5 animationCurve:NSAnimationEaseInOut];
    if (self) {
        _viewAnimations = [viewAnimations copy] ?: @[];
    }
    return self;
}

- (instancetype)init
{
    return [self initWithViewAnimations:@[]];
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    /* TODO(stage2): decode the descriptor array. */
    return [self initWithViewAnimations:@[]];
}

- (void)encodeWithCoder:(NSCoder *)coder { /* TODO(stage2) */ }

- (NSArray<NSDictionary<NSViewAnimationKey, id> *> *)viewAnimations { return _viewAnimations; }

- (void)setViewAnimations:(NSArray<NSDictionary<NSViewAnimationKey, id> *> *)v
{
    _viewAnimations = [v copy] ?: @[];
    /* TODO(stage2): if already running, rebuild the per-frame info maps. */
}

- (void)setCurrentProgress:(NSAnimationProgress)progress
{
    [super setCurrentProgress:progress];

    /* Apply the curve-mapped value so motion matches the animation curve. */
    float t = self.currentValue;

    for (NSDictionary<NSViewAnimationKey, id> *info in _viewAnimations) {
        id target = info[NSViewAnimationTargetKey];
        NSValue *startV = info[NSViewAnimationStartFrameKey];
        NSValue *endV   = info[NSViewAnimationEndFrameKey];
        if (target && startV && endV &&
            [target respondsToSelector:@selector(setFrame:)]) {
            NSRect s = startV.rectValue, e = endV.rectValue;
            NSRect cur = NSMakeRect(
                s.origin.x    + (e.origin.x    - s.origin.x)    * t,
                s.origin.y    + (e.origin.y    - s.origin.y)    * t,
                s.size.width  + (e.size.width  - s.size.width)  * t,
                s.size.height + (e.size.height - s.size.height) * t);
            /* -setFrame: has the same selector/signature on NSView; apply it. */
            void (*setFrame)(id, SEL, NSRect) = (void (*)(id, SEL, NSRect))objc_msgSend;
            setFrame(target, @selector(setFrame:), cur);
        }
        /* TODO(stage2): NSViewAnimationEffectKey fade = interpolate alphaValue
         * (fade-in 0→1, fade-out 1→0) and order the window in/out at the ends. */
    }
}

- (id)copyWithZone:(NSZone *)zone
{
    NSViewAnimation *c = [super copyWithZone:zone];
    c->_viewAnimations = [_viewAnimations copy];
    return c;
}

@end
