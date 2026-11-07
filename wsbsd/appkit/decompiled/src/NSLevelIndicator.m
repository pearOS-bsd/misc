/* NSLevelIndicator.m — 1:1 (core). Delegates to NSLevelIndicatorCell. */
#import "NSLevelIndicator.h"

@implementation NSLevelIndicator

+ (Class)cellClass { return [NSLevelIndicatorCell class]; }
- (NSLevelIndicatorCell *)li { return (NSLevelIndicatorCell *)self.cell; }

- (double)minValue { return [self.li minValue]; }
- (void)setMinValue:(double)v { [self.li setMinValue:v]; }
- (double)maxValue { return [self.li maxValue]; }
- (void)setMaxValue:(double)v { [self.li setMaxValue:v]; }
- (double)warningValue { return [self.li warningValue]; }
- (void)setWarningValue:(double)v { [self.li setWarningValue:v]; }
- (double)criticalValue { return [self.li criticalValue]; }
- (void)setCriticalValue:(double)v { [self.li setCriticalValue:v]; }
- (NSInteger)numberOfTickMarks { return [self.li numberOfTickMarks]; }
- (void)setNumberOfTickMarks:(NSInteger)n { [self.li setNumberOfTickMarks:n]; }

@end
