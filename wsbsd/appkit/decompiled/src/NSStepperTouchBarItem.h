/*
 * NSStepperTouchBarItem.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSStepperTouchBarItem (: NSTouchBarItem), a Touch Bar stepper.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSStepperTouchBarItem_interface.txt.
 *
 * Measured on this Mac: minValue 0, maxValue 59, increment 1, value 0; the
 * formatter is readonly (set by the factory). This core reproduces the numeric
 * value model (value clamped to [min,max]) + target/action + factories. The
 * backing stepper view (-view) and drawing handler are TODO(stage2).
 */

#import "NSTouchBarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSFormatter;

@interface NSStepperTouchBarItem : NSTouchBarItem

+ (instancetype)stepperTouchBarItemWithIdentifier:(NSString *)identifier formatter:(NSFormatter *)formatter;
+ (instancetype)stepperTouchBarItemWithIdentifier:(NSString *)identifier drawingHandler:(void (^)(id dstRect, double value))drawingHandler;

@property (nullable, readonly, strong) NSFormatter *formatter;
@property double maxValue;      /* default 59 */
@property double minValue;      /* default 0  */
@property double increment;     /* default 1  */
@property double value;         /* default 0, clamped to [min,max] */
@property (nullable, weak) id target;
@property SEL action;
@property (copy) NSString *customizationLabel;

@end

NS_ASSUME_NONNULL_END
