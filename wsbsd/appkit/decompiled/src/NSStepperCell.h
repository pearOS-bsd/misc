/*
 * NSStepperCell.h — 1:1 reimplementation of AppKit's NSStepperCell (core).
 *
 * NSActionCell subclass. Evidence ../evidence/stepper: the shipping cell keeps
 * minValue/maxValue/increment/valueWraps/autorepeat in a _stepperModel object
 * (ivar 0xd98) and forwards to it. We hold them directly and expose the same
 * contract; TODO(stage2): the _stepperModel object.
 */
#import "NSActionCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSStepperCell : NSActionCell
@property double minValue;
@property double maxValue;
@property double increment;
@property BOOL valueWraps;
@property BOOL autorepeat;
@end

NS_ASSUME_NONNULL_END
