/*
 * NSScrubberLayoutAttributes.h — 1:1 reimplementation of AppKit's
 * NSScrubberLayoutAttributes, the per-item layout record an NSScrubberLayout
 * produces.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSScrubberLayoutAttributes_interface.txt. Real ivars: _itemIndex,
 * _frame, _alpha, _escapes.
 *
 * Measured on this Mac: init gives itemIndex=-1, alpha=1.0, frame zero,
 * escapesFromScrollView=NO; +layoutAttributesForItemAtIndex: sets the index;
 * -isEqual: compares itemIndex, frame and alpha. Pure value object — no stage2.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSScrubberLayoutAttributes : NSObject <NSCopying>

+ (instancetype)layoutAttributesForItemAtIndex:(NSInteger)index;

@property NSInteger itemIndex;      /* default -1 */
@property NSRect frame;             /* default zero */
@property CGFloat alpha;            /* default 1.0 */
@property BOOL escapesFromScrollView; /* default NO */

@end

NS_ASSUME_NONNULL_END
