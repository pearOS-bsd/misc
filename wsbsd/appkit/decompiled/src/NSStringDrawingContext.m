/*
 * NSStringDrawingContext.m — 1:1 (core). See the header for the evidence.
 *
 * Stores the input knobs (minimumScaleFactor/minimumTrackingAdjustment/
 * maximumNumberOfLines). The outputs start empty (actualScaleFactor 1.0,
 * totalBounds zero) and are filled by the drawing pass through
 * -_setActualScaleFactor:totalBounds:. The draw itself is stage2.
 */
#import "NSStringDrawingContext.h"

@implementation NSStringDrawingContext {
    CGFloat _minimumScaleFactor;
    CGFloat _minimumTrackingAdjustment;
    NSUInteger _maximumNumberOfLines;
    CGFloat _actualScaleFactor;
    CGFloat _actualTrackingAdjustment;
    CGRect _totalBounds;
}

- (instancetype)init
{
    self = [super init];
    if (self) { _actualScaleFactor = 1.0; _totalBounds = CGRectZero; }
    return self;
}

- (CGFloat)minimumScaleFactor { return _minimumScaleFactor; }
- (void)setMinimumScaleFactor:(CGFloat)v { _minimumScaleFactor = v; }
- (CGFloat)minimumTrackingAdjustment { return _minimumTrackingAdjustment; }
- (void)setMinimumTrackingAdjustment:(CGFloat)v { _minimumTrackingAdjustment = v; }
- (NSUInteger)maximumNumberOfLines { return _maximumNumberOfLines; }
- (void)setMaximumNumberOfLines:(NSUInteger)v { _maximumNumberOfLines = v; }

- (CGFloat)actualScaleFactor { return _actualScaleFactor; }
- (CGFloat)actualTrackingAdjustment { return _actualTrackingAdjustment; }
- (CGRect)totalBounds { return _totalBounds; }

- (void)_setActualScaleFactor:(CGFloat)scale totalBounds:(CGRect)bounds
{
    _actualScaleFactor = scale;
    _totalBounds = bounds;
}

@end
