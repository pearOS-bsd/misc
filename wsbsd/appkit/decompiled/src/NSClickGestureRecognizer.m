/*
 * NSClickGestureRecognizer.m — 1:1 (core). Evidence ../evidence/click:
 * numberOfClicksRequired 0x18513634c ([self+0xd0c]), buttonMask 0x185091ea0
 * ([self+0xd08], read under @synchronized(self)).
 */
#import "NSClickGestureRecognizer.h"

@implementation NSClickGestureRecognizer {
    NSInteger _numberOfClicksRequired;   /* 0xd0c */
    NSUInteger _buttonMask;              /* 0xd08 */
}

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self) { _numberOfClicksRequired = 1; _buttonMask = 0x1; }  /* 1 click, primary button */
    return self;
}

- (NSInteger)numberOfClicksRequired { return _numberOfClicksRequired; }
- (void)setNumberOfClicksRequired:(NSInteger)n { _numberOfClicksRequired = n; }

- (NSUInteger)buttonMask { @synchronized(self) { return _buttonMask; } }
- (void)setButtonMask:(NSUInteger)buttonMask { @synchronized(self) { _buttonMask = buttonMask; } }

@end
