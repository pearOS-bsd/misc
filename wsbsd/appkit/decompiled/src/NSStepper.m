/*
 * NSStepper.m — 1:1 reimplementation of AppKit's NSStepper (core).
 * Evidence ../evidence/stepper: minValue 0x185691b4c etc. each do
 * NSControlDelegatesToCell ? [cell <sel>] : <fallback>, then return the cell's.
 */
#import "NSStepper.h"

@implementation NSStepper

+ (Class)cellClass { return [NSStepperCell class]; }

- (NSStepperCell *)stepperCell { return (NSStepperCell *)self.cell; }

- (double)minValue { return [self.stepperCell minValue]; }
- (void)setMinValue:(double)minValue { [self.stepperCell setMinValue:minValue]; }
- (double)maxValue { return [self.stepperCell maxValue]; }
- (void)setMaxValue:(double)maxValue { [self.stepperCell setMaxValue:maxValue]; }
- (double)increment { return [self.stepperCell increment]; }
- (void)setIncrement:(double)increment { [self.stepperCell setIncrement:increment]; }
- (BOOL)valueWraps { return [self.stepperCell valueWraps]; }
- (void)setValueWraps:(BOOL)valueWraps { [self.stepperCell setValueWraps:valueWraps]; }
- (BOOL)autorepeat { return [self.stepperCell autorepeat]; }
- (void)setAutorepeat:(BOOL)autorepeat { [self.stepperCell setAutorepeat:autorepeat]; }

@end
