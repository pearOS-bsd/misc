/*
 * NSStringDrawingContext.h — 1:1 reimplementation (core). NSObject.
 * Public AppKit text API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSStringDrawingContext : NSObject <NSLayoutManagerDelegate> {
 *       d _minimumScaleFactor;  d _minimumTrackingAdjustment;
 *       d _actualScaleFactor;  d _actualTrackingAdjustment;  {CGRect} _totalBounds;
 *       Q _maximumNumberOfLines;  …
 *   }
 *   -minimumScaleFactor -setMinimumScaleFactor: -actualScaleFactor -totalBounds
 *   -maximumNumberOfLines
 *
 * Inputs (minimumScaleFactor, minimumTrackingAdjustment, maximumNumberOfLines)
 * tune a string-drawing pass; outputs (actualScaleFactor, totalBounds) are
 * filled in by the draw. The core stores the inputs and exposes the outputs;
 * the drawing that computes them is stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSStringDrawingContext : NSObject

@property CGFloat minimumScaleFactor;
@property CGFloat minimumTrackingAdjustment;
@property NSUInteger maximumNumberOfLines;

@property (readonly) CGFloat actualScaleFactor;
@property (readonly) CGFloat actualTrackingAdjustment;
@property (readonly) CGRect totalBounds;

/* the drawing pass fills the outputs through these (stage2 upstream). */
- (void)_setActualScaleFactor:(CGFloat)scale totalBounds:(CGRect)bounds;

@end

NS_ASSUME_NONNULL_END
