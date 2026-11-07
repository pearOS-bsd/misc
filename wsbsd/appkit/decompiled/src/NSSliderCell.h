/*
 * NSSliderCell.h — 1:1 reimplementation of AppKit's NSSliderCell (core).
 * NSActionCell subclass. Evidence ../evidence/slider: minValue/maxValue/
 * numberOfTickMarks/altIncrementValue are direct ivars (getters read them);
 * the setters also sync a _sliderModel (stage2).
 */
#import "NSActionCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSliderCell : NSActionCell
@property double minValue;
@property double maxValue;
@property double altIncrementValue;
@property NSInteger numberOfTickMarks;
@end

NS_ASSUME_NONNULL_END
