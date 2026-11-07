/*
 * NSProgressIndicator.h — 1:1 reimplementation of AppKit's NSProgressIndicator (core).
 *
 * NSView subclass. Evidence ../evidence/progress: minValue/maxValue/doubleValue
 * are direct double ivars; setDoubleValue: clamps to [minValue, maxValue];
 * incrementBy: adds then clamps. isIndeterminate/style live in an aux object
 * (ivar at 0x774) — kept directly here (TODO(stage2): the aux renderer, drawing,
 * startAnimation:/stopAnimation:).
 */
#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSProgressIndicatorStyle) {
    NSProgressIndicatorStyleBar     = 0,
    NSProgressIndicatorStyleSpinning = 1,
};

@interface NSProgressIndicator : NSView

@property double minValue;
@property double maxValue;
@property double doubleValue;
@property (getter=isIndeterminate) BOOL indeterminate;
@property NSProgressIndicatorStyle style;

- (void)incrementBy:(double)delta;

@end

NS_ASSUME_NONNULL_END
