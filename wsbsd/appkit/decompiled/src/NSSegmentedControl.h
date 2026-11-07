/* NSSegmentedControl.h — 1:1 (core). NSControl backed by NSSegmentedCell; delegates.
 * Evidence ../evidence/seg (segmentCount 0x184fb909c -> [cell segmentCount]). */
#import "NSControl.h"
#import "NSSegmentedCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSegmentedControl : NSControl
@property NSInteger segmentCount;
@property NSInteger selectedSegment;
- (void)setLabel:(NSString *)label forSegment:(NSInteger)segment;
- (nullable NSString *)labelForSegment:(NSInteger)segment;
- (void)setWidth:(CGFloat)width forSegment:(NSInteger)segment;
- (CGFloat)widthForSegment:(NSInteger)segment;
@end

NS_ASSUME_NONNULL_END
