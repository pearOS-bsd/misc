/*
 * NSStepper.h — 1:1 reimplementation of AppKit's NSStepper (core).
 * NSControl subclass backed by NSStepperCell; every property delegates to the
 * cell (NSControlDelegatesToCell, evidence ../evidence/stepper).
 */
#import "NSControl.h"
#import "NSStepperCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSStepper : NSControl
@property double minValue;
@property double maxValue;
@property double increment;
@property BOOL valueWraps;
@property BOOL autorepeat;
@end

NS_ASSUME_NONNULL_END
