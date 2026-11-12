/*
 * NSStepperTouchBarItem.m — behavioral-1:1 core. See NSStepperTouchBarItem.h.
 */

#import "NSStepperTouchBarItem.h"

@implementation NSStepperTouchBarItem {
    NSFormatter *_formatter;
    void (^_drawingHandler)(id, double);
    double _minValue, _maxValue, _increment, _value;
    __weak id _target;
    SEL _action;
    NSString *_customizationLabel;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super initWithIdentifier:identifier];
    if (self) {
        _minValue = 0; _maxValue = 59; _increment = 1; _value = 0;  /* measured */
        _customizationLabel = @"";
    }
    return self;
}

+ (instancetype)stepperTouchBarItemWithIdentifier:(NSString *)identifier formatter:(NSFormatter *)formatter
{
    NSStepperTouchBarItem *item = [[self alloc] initWithIdentifier:identifier];
    item->_formatter = formatter;
    return item;
}

+ (instancetype)stepperTouchBarItemWithIdentifier:(NSString *)identifier drawingHandler:(void (^)(id, double))drawingHandler
{
    NSStepperTouchBarItem *item = [[self alloc] initWithIdentifier:identifier];
    item->_drawingHandler = [drawingHandler copy];
    return item;
}

- (NSFormatter *)formatter { return _formatter; }
- (double)minValue { return _minValue; }
- (void)setMinValue:(double)v { _minValue = v; if (_value < _minValue) _value = _minValue; }
- (double)maxValue { return _maxValue; }
- (void)setMaxValue:(double)v { _maxValue = v; if (_value > _maxValue) _value = _maxValue; }
- (double)increment { return _increment; }
- (void)setIncrement:(double)v { _increment = v; }
- (double)value { return _value; }
- (void)setValue:(double)v
{
    if (v < _minValue) v = _minValue;
    if (v > _maxValue) v = _maxValue;
    _value = v;
}
- (id)target { return _target; }
- (void)setTarget:(id)t { _target = t; }
- (SEL)action { return _action; }
- (void)setAction:(SEL)a { _action = a; }
- (NSString *)customizationLabel { return _customizationLabel; }
- (void)setCustomizationLabel:(NSString *)s { _customizationLabel = [s copy] ?: @""; }

@end
