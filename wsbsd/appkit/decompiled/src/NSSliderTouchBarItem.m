/*
 * NSSliderTouchBarItem.m — behavioral-1:1 core. See NSSliderTouchBarItem.h.
 */

#import "NSSliderTouchBarItem.h"
#import "NSSlider.h"

@implementation NSSliderTouchBarItem {
    NSSlider *_slider;
    double _value;
    double _minValue, _maxValue;
    double _incrementValue;
    NSString *_label;
    double _minimumSliderWidth, _maximumSliderWidth, _valueAccessoryWidth;
    NSSliderAccessory *_minimumValueAccessory, *_maximumValueAccessory;
    __weak id _target;
    SEL _action;
    NSString *_customizationLabel;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super initWithIdentifier:identifier];
    if (self) {
        _slider = [[NSSlider alloc] init];
        _minValue = 0; _maxValue = 1;                  /* measured */
        _slider.minValue = 0; _slider.maxValue = 1;
        _value = 0;
        _minimumSliderWidth = 64;                      /* measured */
        _maximumSliderWidth = CGFLOAT_MAX;             /* measured */
        _valueAccessoryWidth = 36;                     /* measured */
        _customizationLabel = @"";
    }
    return self;
}

- (NSSlider *)slider { return _slider; }
- (void)setSlider:(NSSlider *)s { _slider = s; }

- (double)_clamp:(double)v
{
    if (v < _minValue) v = _minValue;
    if (v > _maxValue) v = _maxValue;
    return v;
}

- (double)doubleValue { return _value; }
- (void)setDoubleValue:(double)v { _value = [self _clamp:v]; }
- (double)value { return _value; }
- (void)setValue:(double)v { _value = [self _clamp:v]; }

- (double)minimumValue { return _minValue; }
- (void)setMinimumValue:(double)v { _minValue = v; _slider.minValue = v; _value = [self _clamp:_value]; }
- (double)maximumValue { return _maxValue; }
- (void)setMaximumValue:(double)v { _maxValue = v; _slider.maxValue = v; _value = [self _clamp:_value]; }
- (double)incrementValue { return _incrementValue; }
- (void)setIncrementValue:(double)v { _incrementValue = v; _slider.altIncrementValue = v; }

- (NSString *)label { return _label; }
- (void)setLabel:(NSString *)s { _label = [s copy]; }
- (double)minimumSliderWidth { return _minimumSliderWidth; }
- (void)setMinimumSliderWidth:(double)w { _minimumSliderWidth = w; }
- (double)maximumSliderWidth { return _maximumSliderWidth; }
- (void)setMaximumSliderWidth:(double)w { _maximumSliderWidth = w; }
- (double)valueAccessoryWidth { return _valueAccessoryWidth; }
- (void)setValueAccessoryWidth:(double)w { _valueAccessoryWidth = w; }
- (NSSliderAccessory *)minimumValueAccessory { return _minimumValueAccessory; }
- (void)setMinimumValueAccessory:(NSSliderAccessory *)a { _minimumValueAccessory = a; }
- (NSSliderAccessory *)maximumValueAccessory { return _maximumValueAccessory; }
- (void)setMaximumValueAccessory:(NSSliderAccessory *)a { _maximumValueAccessory = a; }
- (id)target { return _target; }
- (void)setTarget:(id)t { _target = t; }
- (SEL)action { return _action; }
- (void)setAction:(SEL)a { _action = a; }
- (NSString *)customizationLabel { return _customizationLabel; }
- (void)setCustomizationLabel:(NSString *)s { _customizationLabel = [s copy] ?: @""; }

@end
