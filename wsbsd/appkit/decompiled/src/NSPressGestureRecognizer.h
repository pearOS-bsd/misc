/*
 * NSPressGestureRecognizer.h — 1:1 (core). NSGestureRecognizer subclass.
 * Evidence ../evidence/press: minimumPressDuration, allowableMovement @0xc98,
 * buttonMask @0xc8c, numberOfTouchesRequired — all accessed under @synchronized.
 * Long-press timing/tracking is stage2.
 */
#import "NSGestureRecognizer.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSPressGestureRecognizer : NSGestureRecognizer
@property NSTimeInterval minimumPressDuration;
@property CGFloat allowableMovement;
@property NSUInteger buttonMask;
@property NSInteger numberOfTouchesRequired;
@end

NS_ASSUME_NONNULL_END
