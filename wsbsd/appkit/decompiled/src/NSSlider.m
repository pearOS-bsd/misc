/*
 * NSSlider.m — 1:1 reimplementation (core). Delegates to NSSliderCell.
 * Evidence ../evidence/slider.
 */
#import "NSSlider.h"

@implementation NSSlider

+ (Class)cellClass { return [NSSliderCell class]; }

- (NSSliderCell *)sliderCell { return (NSSliderCell *)self.cell; }

- (double)minValue { return [self.sliderCell minValue]; }
- (void)setMinValue:(double)minValue { [self.sliderCell setMinValue:minValue]; }
- (double)maxValue { return [self.sliderCell maxValue]; }
- (void)setMaxValue:(double)maxValue { [self.sliderCell setMaxValue:maxValue]; }
- (double)altIncrementValue { return [self.sliderCell altIncrementValue]; }
- (void)setAltIncrementValue:(double)v { [self.sliderCell setAltIncrementValue:v]; }
- (NSInteger)numberOfTickMarks { return [self.sliderCell numberOfTickMarks]; }
- (void)setNumberOfTickMarks:(NSInteger)n { [self.sliderCell setNumberOfTickMarks:n]; }

@end
