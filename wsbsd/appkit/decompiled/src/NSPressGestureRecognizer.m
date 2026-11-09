/*
 * NSPressGestureRecognizer.m — 1:1 (core). Evidence ../evidence/press:
 * minimumPressDuration 0x185135264, allowableMovement 0x185bd1224 (@0xc98),
 * buttonMask 0x185135120 (@0xc8c) — all under @synchronized(self).
 */
#import "NSPressGestureRecognizer.h"

@implementation NSPressGestureRecognizer {
    NSTimeInterval _minimumPressDuration;
    CGFloat _allowableMovement;          /* 0xc98 */
    NSUInteger _buttonMask;              /* 0xc8c */
    NSInteger _numberOfTouchesRequired;
}

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self) {
        _minimumPressDuration = 0.5;   /* AppKit default */
        _allowableMovement = 10.0;
        _buttonMask = 0x1;
        _numberOfTouchesRequired = 1;
    }
    return self;
}

- (NSTimeInterval)minimumPressDuration { @synchronized(self) { return _minimumPressDuration; } }
- (void)setMinimumPressDuration:(NSTimeInterval)v { @synchronized(self) { _minimumPressDuration = v; } }
- (CGFloat)allowableMovement { @synchronized(self) { return _allowableMovement; } }
- (void)setAllowableMovement:(CGFloat)v { @synchronized(self) { _allowableMovement = v; } }
- (NSUInteger)buttonMask { @synchronized(self) { return _buttonMask; } }
- (void)setButtonMask:(NSUInteger)v { @synchronized(self) { _buttonMask = v; } }
- (NSInteger)numberOfTouchesRequired { @synchronized(self) { return _numberOfTouchesRequired; } }
- (void)setNumberOfTouchesRequired:(NSInteger)v { @synchronized(self) { _numberOfTouchesRequired = v; } }

@end
