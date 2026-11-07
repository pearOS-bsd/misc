/*
 * NSSliderCell.m — 1:1 reimplementation (core).
 * Evidence ../evidence/slider: _minValue 0xd70, _maxValue 0xd74,
 * _numberOfTickMarks 0xd78 (direct). Getters read the ivar directly
 * (minValue 0x1850e9868 etc.); setters store and also push into a _sliderModel
 * (-[NSSliderCell _sliderModel]) — the model sync is stage2.
 */
#import "NSSliderCell.h"

@implementation NSSliderCell {
    double _minValue;             /* 0xd70 */
    double _maxValue;             /* 0xd74 */
    double _altIncrementValue;
    NSInteger _numberOfTickMarks; /* 0xd78 */
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _minValue = 0.0;
        _maxValue = 1.0;              /* conventional default; exact init is stage2 */
        _altIncrementValue = -1.0;   /* -1 == no alternate increment */
        _numberOfTickMarks = 0;
    }
    return self;
}

- (double)minValue { return _minValue; }
- (void)setMinValue:(double)minValue { _minValue = minValue; }
- (double)maxValue { return _maxValue; }
- (void)setMaxValue:(double)maxValue { _maxValue = maxValue; }
- (double)altIncrementValue { return _altIncrementValue; }
- (void)setAltIncrementValue:(double)altIncrementValue { _altIncrementValue = altIncrementValue; }
- (NSInteger)numberOfTickMarks { return _numberOfTickMarks; }
- (void)setNumberOfTickMarks:(NSInteger)numberOfTickMarks { _numberOfTickMarks = numberOfTickMarks; }

@end
