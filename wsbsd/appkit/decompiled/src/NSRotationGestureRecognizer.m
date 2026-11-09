/*
 * NSRotationGestureRecognizer.m — 1:1 (core). Evidence ../evidence/mag:
 * rotation 0x1855ca1f0 reads an internal angle and scales it by a constant;
 * setRotation: 0x1855ca220 scales the input back. We store radians directly;
 * TODO(stage2): the exact internal unit and the two scaling constants.
 */
#import "NSRotationGestureRecognizer.h"

@implementation NSRotationGestureRecognizer {
    CGFloat _rotation;   /* radians */
}

- (CGFloat)rotation { return _rotation; }
- (void)setRotation:(CGFloat)rotation { _rotation = rotation; }

@end
