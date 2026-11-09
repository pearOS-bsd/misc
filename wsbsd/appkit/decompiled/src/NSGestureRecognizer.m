/*
 * NSGestureRecognizer.m — 1:1 (core). Evidence ../evidence/gr:
 * target 0x184f63cf8 (weak @0x20), action 0x184f63d10 (PAC SEL @0x28), state via
 * _state (word @0x58). isEnabled 0x18513444c gates on _NSIsGesturesFrameworkEnabled.
 * We hold state/enabled plainly; the recognition dispatch is stage2.
 */
#import "NSGestureRecognizer.h"

@implementation NSGestureRecognizer {
    NSGestureRecognizerState _state;   /* packed @0x58 in the binary */
    BOOL _enabled;
    __weak id _target;                 /* 0x20 */
    SEL _action;                       /* 0x28 */
}

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super init];
    if (self) {
        _target = target;
        _action = action;
        _enabled = YES;
        _state = NSGestureRecognizerStatePossible;
    }
    return self;
}

- (instancetype)init { return [self initWithTarget:nil action:NULL]; }

- (NSGestureRecognizerState)state { return _state; }

- (BOOL)isEnabled { return _enabled; }
- (void)setEnabled:(BOOL)enabled { _enabled = enabled; }

- (id)target { return _target; }
- (void)setTarget:(id)target { _target = target; }
- (SEL)action { return _action; }
- (void)setAction:(SEL)action { _action = action; }

/* internal: the recognizer subclasses drive the state machine through this. */
- (void)_setState:(NSGestureRecognizerState)state { _state = state; }

@end
