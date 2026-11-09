/*
 * NSMagnificationGestureRecognizer.h — 1:1 (core). NSGestureRecognizer subclass.
 * Evidence ../evidence/mag: magnification @0x1c0 (double, direct). Pinch tracking
 * is stage2.
 */
#import "NSGestureRecognizer.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSMagnificationGestureRecognizer : NSGestureRecognizer
@property CGFloat magnification;
@end

NS_ASSUME_NONNULL_END
