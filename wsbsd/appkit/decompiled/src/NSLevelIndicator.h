/* NSLevelIndicator.h — 1:1 (core). NSControl backed by NSLevelIndicatorCell;
 * props delegate to the cell (minValue 0x18562d3f8 -> [cell minValue]). */
#import "NSControl.h"
#import "NSLevelIndicatorCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSLevelIndicator : NSControl
@property double minValue;
@property double maxValue;
@property double warningValue;
@property double criticalValue;
@property NSInteger numberOfTickMarks;
@end

NS_ASSUME_NONNULL_END
