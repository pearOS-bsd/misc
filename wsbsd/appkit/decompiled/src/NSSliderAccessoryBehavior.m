/*
 * NSSliderAccessoryBehavior.m — 1:1 (core). See the header for the evidence.
 *
 * A behavior is either a built-in type (automatic / value-reset / value-step) or
 * a custom handler / target-action. handleAction: runs the handler, or sends the
 * action to the target, or — for a built-in type — is a no-op here (the slider
 * value-reset/step effect is stage2).
 */
#import "NSSliderAccessoryBehavior.h"

typedef NS_ENUM(NSInteger, NSSliderAccessoryBehaviorType) {
    NSSliderAccessoryBehaviorTypeAutomatic = 0,
    NSSliderAccessoryBehaviorTypeValueReset = 1,
    NSSliderAccessoryBehaviorTypeValueStep = 2,
    NSSliderAccessoryBehaviorTypeTargetAction = 3,
    NSSliderAccessoryBehaviorTypeHandler = 4,
};

@implementation NSSliderAccessoryBehavior {
    NSSliderAccessoryBehaviorType _type;
    __weak id _target;
    SEL _action;
    void (^_handler)(id);
}

+ (instancetype)automaticBehavior  { NSSliderAccessoryBehavior *b = [[self alloc] init]; b->_type = NSSliderAccessoryBehaviorTypeAutomatic; return b; }
+ (instancetype)valueResetBehavior { NSSliderAccessoryBehavior *b = [[self alloc] init]; b->_type = NSSliderAccessoryBehaviorTypeValueReset; return b; }
+ (instancetype)valueStepBehavior  { NSSliderAccessoryBehavior *b = [[self alloc] init]; b->_type = NSSliderAccessoryBehaviorTypeValueStep; return b; }

+ (instancetype)behaviorWithTarget:(id)target action:(SEL)action
{
    NSSliderAccessoryBehavior *b = [[self alloc] init];
    b->_type = NSSliderAccessoryBehaviorTypeTargetAction;
    b->_target = target; b->_action = action;
    return b;
}
+ (instancetype)behaviorWithHandler:(void (^)(id))handler
{
    NSSliderAccessoryBehavior *b = [[self alloc] init];
    b->_type = NSSliderAccessoryBehaviorTypeHandler;
    b->_handler = [handler copy];
    return b;
}

- (void)handleAction:(id)sender
{
    if (_type == NSSliderAccessoryBehaviorTypeHandler) {
        if (_handler) _handler(sender);
    } else if (_type == NSSliderAccessoryBehaviorTypeTargetAction) {
        if (_target && _action) {
            IMP imp = [_target methodForSelector:_action];
            if (imp) ((void (*)(id, SEL, id))imp)(_target, _action, sender);
        }
    }
    /* built-in types apply their slider effect here — stage2 */
}

- (id)copyWithZone:(NSZone *)zone
{
    NSSliderAccessoryBehavior *b = [[NSSliderAccessoryBehavior alloc] init];
    b->_type = _type; b->_target = _target; b->_action = _action; b->_handler = [_handler copy];
    return b;
}

@end
