/*
 * NSLevelIndicatorCell.h — 1:1 reimplementation (core). NSActionCell subclass.
 * Evidence ../evidence/level: minValue/maxValue/warningValue/criticalValue are
 * direct double ivars, numberOfTickMarks a direct int.
 */
#import "NSActionCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSLevelIndicatorCell : NSActionCell
@property double minValue;
@property double maxValue;
@property double warningValue;
@property double criticalValue;
@property NSInteger numberOfTickMarks;
@end

NS_ASSUME_NONNULL_END
