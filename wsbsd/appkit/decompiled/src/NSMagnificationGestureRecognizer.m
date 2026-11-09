/*
 * NSMagnificationGestureRecognizer.m — 1:1 (core). Evidence ../evidence/mag:
 * magnification 0x185376dd4 ([self+0x1c0]), setMagnification: 0x185376de8.
 */
#import "NSMagnificationGestureRecognizer.h"

@implementation NSMagnificationGestureRecognizer {
    CGFloat _magnification;   /* 0x1c0 */
}

- (CGFloat)magnification { return _magnification; }
- (void)setMagnification:(CGFloat)magnification { _magnification = magnification; }

@end
