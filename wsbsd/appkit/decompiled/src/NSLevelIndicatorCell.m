/*
 * NSLevelIndicatorCell.m — 1:1 (core). Evidence ../evidence/level:
 * _maxValue 0x388, _minValue 0x390, _warningValue 0x394, _criticalValue 0x398,
 * _numberOfTickMarks 0x39c. Getters read the ivar directly.
 */
#import "NSLevelIndicatorCell.h"

@implementation NSLevelIndicatorCell {
    double _maxValue;             /* 0x388 */
    double _minValue;             /* 0x390 */
    double _warningValue;         /* 0x394 */
    double _criticalValue;        /* 0x398 */
    NSInteger _numberOfTickMarks; /* 0x39c */
}

- (instancetype)init
{
    self = [super init];
    if (self) { _minValue = 0.0; _maxValue = 100.0; }  /* conventional; exact init stage2 */
    return self;
}

- (double)minValue { return _minValue; }
- (void)setMinValue:(double)v { _minValue = v; }
- (double)maxValue { return _maxValue; }
- (void)setMaxValue:(double)v { _maxValue = v; }
- (double)warningValue { return _warningValue; }
- (void)setWarningValue:(double)v { _warningValue = v; }
- (double)criticalValue { return _criticalValue; }
- (void)setCriticalValue:(double)v { _criticalValue = v; }
- (NSInteger)numberOfTickMarks { return _numberOfTickMarks; }
- (void)setNumberOfTickMarks:(NSInteger)n { _numberOfTickMarks = n; }

@end
