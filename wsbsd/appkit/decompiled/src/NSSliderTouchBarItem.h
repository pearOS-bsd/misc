/*
 * NSSliderTouchBarItem.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSSliderTouchBarItem (: NSTouchBarItem), a slider in the Touch Bar.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSSliderTouchBarItem_interface.txt.
 *
 * Measured on this Mac: the slider is auto-created (minValue 0, maxValue 1);
 * doubleValue/value delegate to the slider and clamp to [min,max]; defaults
 * minimumSliderWidth 64, maximumSliderWidth CGFLOAT_MAX, valueAccessoryWidth 36,
 * label nil. This core reproduces the numeric value model (clamped), the min/max
 * accessories, widths and target/action. The backing item view is TODO(stage2).
 */

#import "NSTouchBarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSSlider, NSSliderAccessory;

@interface NSSliderTouchBarItem : NSTouchBarItem

@property (strong) NSSlider *slider;
@property double doubleValue;                   /* clamped to [minimumValue, maximumValue] */
@property double value;                         /* == doubleValue */
@property double minimumValue;                  /* default 0 */
@property double maximumValue;                  /* default 1 */
@property double incrementValue;
@property (nullable, copy) NSString *label;
@property double minimumSliderWidth;            /* default 64 */
@property double maximumSliderWidth;            /* default CGFLOAT_MAX */
@property double valueAccessoryWidth;           /* default 36 */
@property (nullable, strong) NSSliderAccessory *minimumValueAccessory;
@property (nullable, strong) NSSliderAccessory *maximumValueAccessory;
@property (nullable, weak) id target;
@property SEL action;
@property (copy) NSString *customizationLabel;

@end

NS_ASSUME_NONNULL_END
