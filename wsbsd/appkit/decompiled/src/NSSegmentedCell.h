/*
 * NSSegmentedCell.h — 1:1 reimplementation (core). NSActionCell subclass.
 * Evidence ../evidence/seg: segmentCount reads a segments array (@0x550),
 * selectedSegment a field (@0x548); setSegmentCount: raises when count > 0x800.
 * We model the per-segment data as an array of items; the shipping packed
 * segment records are stage2.
 */
#import "NSActionCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSegmentedCell : NSActionCell
@property NSInteger segmentCount;
@property NSInteger selectedSegment;
- (void)setLabel:(NSString *)label forSegment:(NSInteger)segment;
- (nullable NSString *)labelForSegment:(NSInteger)segment;
- (void)setWidth:(CGFloat)width forSegment:(NSInteger)segment;
- (CGFloat)widthForSegment:(NSInteger)segment;
@end

NS_ASSUME_NONNULL_END
