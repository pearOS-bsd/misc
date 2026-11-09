/*
 * NSPanGestureRecognizer.m — 1:1 (core). Evidence ../evidence/pan:
 * buttonMask 0x185134e40 ([self+0x284] under @synchronized), setButtonMask:
 * 0x1850643bc, numberOfTouchesRequired 0x18538f388 ([self+0x27c]).
 */
#import "NSPanGestureRecognizer.h"

@implementation NSPanGestureRecognizer {
    NSUInteger _buttonMask;              /* 0x284 */
    NSInteger _numberOfTouchesRequired;  /* 0x27c */
}

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self) { _buttonMask = 0x1; _numberOfTouchesRequired = 1; }
    return self;
}

- (NSUInteger)buttonMask { @synchronized(self) { return _buttonMask; } }
- (void)setButtonMask:(NSUInteger)buttonMask { @synchronized(self) { _buttonMask = buttonMask; } }

- (NSInteger)numberOfTouchesRequired { return _numberOfTouchesRequired; }
- (void)setNumberOfTouchesRequired:(NSInteger)n { _numberOfTouchesRequired = n; }

@end
