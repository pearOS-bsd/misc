/*
 * NSPanGestureRecognizer.h — 1:1 reimplementation (core). NSGestureRecognizer
 * subclass. Evidence ../evidence/pan: buttonMask @0x284 (accessed under
 * @synchronized), numberOfTouchesRequired @0x27c. Translation/velocity tracking
 * is stage2.
 */
#import "NSGestureRecognizer.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSPanGestureRecognizer : NSGestureRecognizer
@property NSUInteger buttonMask;
@property NSInteger numberOfTouchesRequired;
@end

NS_ASSUME_NONNULL_END
