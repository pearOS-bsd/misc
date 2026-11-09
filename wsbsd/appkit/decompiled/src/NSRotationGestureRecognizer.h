/*
 * NSRotationGestureRecognizer.h — 1:1 (core). NSGestureRecognizer subclass.
 * Evidence ../evidence/mag (rotation 0x1855ca1f0): the shipping accessor stores
 * the angle through a unit-conversion pair of constants; the observable contract
 * is radians in/out, which we keep directly (exact internal scaling is stage2).
 */
#import "NSGestureRecognizer.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSRotationGestureRecognizer : NSGestureRecognizer
@property CGFloat rotation;   /* radians */
@end

NS_ASSUME_NONNULL_END
