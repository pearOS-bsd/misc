/*
 * NSProgressIndicator.m — 1:1 reimplementation (core).
 * Evidence ../evidence/progress: _minValue 0x768, _maxValue 0x76c, _doubleValue
 * 0x770 (direct doubles). setDoubleValue: (0x184f7823c) clamps to [min,max];
 * incrementBy: (0x1856d7f08) adds then clamps; isIndeterminate/style read an aux
 * object at 0x774 (kept directly here, stage2).
 */
#import "NSProgressIndicator.h"

@implementation NSProgressIndicator {
    double _minValue;                   /* 0x768 */
    double _maxValue;                   /* 0x76c */
    double _doubleValue;                /* 0x770 */
    BOOL _indeterminate;                /* shipping: aux object @0x774 (stage2) */
    NSProgressIndicatorStyle _style;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _minValue = 0.0;
        _maxValue = 100.0;              /* AppKit default */
        _doubleValue = 0.0;
        _indeterminate = YES;           /* default is indeterminate */
        _style = NSProgressIndicatorStyleBar;
    }
    return self;
}

- (double)minValue { return _minValue; }                 /* 0x1856d8460 */
- (void)setMinValue:(double)minValue { _minValue = minValue; }   /* 0x1850e6be8 (early-out if equal) */
- (double)maxValue { return _maxValue; }
- (void)setMaxValue:(double)maxValue { _maxValue = maxValue; }

- (double)doubleValue { return _doubleValue; }           /* 0x1851d6ddc */

/* setDoubleValue: clamp to [minValue, maxValue] (0x184f7823c). */
- (void)setDoubleValue:(double)doubleValue
{
    if (doubleValue > _maxValue) doubleValue = _maxValue;
    if (doubleValue < _minValue) doubleValue = _minValue;
    _doubleValue = doubleValue;
}

/* incrementBy: doubleValue += delta, then clamp (0x1856d7f08). */
- (void)incrementBy:(double)delta { [self setDoubleValue:_doubleValue + delta]; }

- (BOOL)isIndeterminate { return _indeterminate; }       /* 0x185005be0 (aux) */
- (void)setIndeterminate:(BOOL)indeterminate { _indeterminate = indeterminate; }
- (NSProgressIndicatorStyle)style { return _style; }     /* 0x185005bf4 (aux) */
- (void)setStyle:(NSProgressIndicatorStyle)style { _style = style; }

@end
