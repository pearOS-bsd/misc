/*
 * NSSliderAccessory.m — behavioral-1:1 core. See NSSliderAccessory.h.
 */

#import "NSSliderAccessory.h"
#import <objc/message.h>

typedef NS_ENUM(NSInteger, NSSliderAccessoryBehaviorKind) {
    kBehaviorAutomatic = 0,
    kBehaviorValueStep = 1,
    kBehaviorValueReset = 2,
    kBehaviorTargetAction = 3,
    kBehaviorHandler = 4,
};

@implementation NSSliderAccessoryBehavior {
    NSSliderAccessoryBehaviorKind _kind;
    __weak id _target;
    SEL _action;
    void (^_handler)(NSSliderAccessory *);
}

+ (instancetype)_behaviorOfKind:(NSSliderAccessoryBehaviorKind)kind
{
    NSSliderAccessoryBehavior *b = [[self alloc] init];
    b->_kind = kind;
    return b;
}

+ (NSSliderAccessoryBehavior *)automaticBehavior  { return [self _behaviorOfKind:kBehaviorAutomatic]; }
+ (NSSliderAccessoryBehavior *)valueStepBehavior  { return [self _behaviorOfKind:kBehaviorValueStep]; }
+ (NSSliderAccessoryBehavior *)valueResetBehavior { return [self _behaviorOfKind:kBehaviorValueReset]; }

+ (NSSliderAccessoryBehavior *)behaviorWithTarget:(id)target action:(SEL)action
{
    NSSliderAccessoryBehavior *b = [self _behaviorOfKind:kBehaviorTargetAction];
    b->_target = target; b->_action = action;
    return b;
}

+ (NSSliderAccessoryBehavior *)behaviorWithHandler:(void (^)(NSSliderAccessory *))handler
{
    NSSliderAccessoryBehavior *b = [self _behaviorOfKind:kBehaviorHandler];
    b->_handler = [handler copy];
    return b;
}

- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)coder {}

- (BOOL)repeatsOnLongPressForAccessory:(NSSliderAccessory *)accessory
{
    /* valueStep repeats while held; the others do not (documented behavior). */
    return _kind == kBehaviorValueStep;
}

- (void)handleAction:(NSSliderAccessory *)accessory
{
    if (_kind == kBehaviorHandler && _handler) { _handler(accessory); return; }
    if (_kind == kBehaviorTargetAction && _target && _action && [_target respondsToSelector:_action]) {
        void (*send)(id, SEL, id) = (void (*)(id, SEL, id))objc_msgSend;
        send(_target, _action, accessory);
    }
    /* automatic/valueStep/valueReset do their built-in slider mutation = stage2 */
}

- (id)copyWithZone:(NSZone *)zone
{
    NSSliderAccessoryBehavior *c = [[[self class] alloc] init];
    c->_kind = _kind; c->_target = _target; c->_action = _action; c->_handler = _handler;
    return c;
}
@end


@implementation NSSliderAccessory {
    NSImage *_image;
    NSSliderAccessoryBehavior *_behavior;
    BOOL _enabled;
}

+ (NSSliderAccessory *)accessoryWithImage:(NSImage *)image
{
    NSSliderAccessory *a = [[self alloc] init];
    a->_image = image;
    return a;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _enabled = YES;    /* measured */
        _behavior = [NSSliderAccessoryBehavior automaticBehavior];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (void)encodeWithCoder:(NSCoder *)coder {}

- (NSSliderAccessoryBehavior *)behavior { return _behavior; }
- (void)setBehavior:(NSSliderAccessoryBehavior *)b { _behavior = [b copy] ?: [NSSliderAccessoryBehavior automaticBehavior]; }

- (BOOL)isEnabled { return _enabled; }
- (void)setEnabled:(BOOL)e { _enabled = e; }

- (BOOL)repeatsOnLongPress { return [_behavior repeatsOnLongPressForAccessory:self]; }

/* internal accessor for tests / later rendering */
- (NSImage *)_image { return _image; }

@end
