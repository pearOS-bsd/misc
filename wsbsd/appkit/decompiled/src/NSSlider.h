/*
 * NSSlider.h — 1:1 reimplementation of AppKit's NSSlider (core).
 * NSControl backed by NSSliderCell; props delegate to the cell
 * (minValue 0x1850e9850 -> [cell minValue], evidence ../evidence/slider).
 */
#import "NSControl.h"
#import "NSSliderCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSlider : NSControl
@property double minValue;
@property double maxValue;
@property double altIncrementValue;
@property NSInteger numberOfTickMarks;
@end

NS_ASSUME_NONNULL_END
