/*
 * NSStepperCell.m — 1:1 reimplementation of AppKit's NSStepperCell (core).
 * Evidence ../evidence/stepper. The getters/setters in the binary load the
 * _stepperModel (ivar 0xd98) and forward (e.g. minValue 0x185693ed4 ->
 * [_stepperModel minValue]). We store the values here; the _stepperModel is
 * stage2. Defaults are AppKit's documented stepper defaults.
 */
#import "NSStepperCell.h"

@implementation NSStepperCell {
    double _minValue;
    double _maxValue;
    double _increment;
    BOOL _valueWraps;
    BOOL _autorepeat;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _minValue = 0.0;
        _maxValue = 59.0;
        _increment = 1.0;
        _valueWraps = YES;
        _autorepeat = YES;
    }
    return self;
}

- (double)minValue { return _minValue; }
- (void)setMinValue:(double)minValue { _minValue = minValue; }
- (double)maxValue { return _maxValue; }
- (void)setMaxValue:(double)maxValue { _maxValue = maxValue; }
- (double)increment { return _increment; }
- (void)setIncrement:(double)increment { _increment = increment; }
- (BOOL)valueWraps { return _valueWraps; }
- (void)setValueWraps:(BOOL)valueWraps { _valueWraps = valueWraps; }
- (BOOL)autorepeat { return _autorepeat; }
- (void)setAutorepeat:(BOOL)autorepeat { _autorepeat = autorepeat; }

@end
