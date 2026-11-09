/*
 * NSClickGestureRecognizer.h — 1:1 reimplementation (core). NSGestureRecognizer
 * subclass. Evidence ../evidence/click: numberOfClicksRequired @0xd0c,
 * buttonMask @0xd08 (accessed under @synchronized). Click detection is stage2.
 */
#import "NSGestureRecognizer.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSClickGestureRecognizer : NSGestureRecognizer
@property NSInteger numberOfClicksRequired;
@property NSUInteger buttonMask;
@end

NS_ASSUME_NONNULL_END
