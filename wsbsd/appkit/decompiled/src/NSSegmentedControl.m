/* NSSegmentedControl.m — 1:1 (core). Delegates to NSSegmentedCell. */
#import "NSSegmentedControl.h"

@implementation NSSegmentedControl

+ (Class)cellClass { return [NSSegmentedCell class]; }
- (NSSegmentedCell *)segCell { return (NSSegmentedCell *)self.cell; }

- (NSInteger)segmentCount { return [self.segCell segmentCount]; }
- (void)setSegmentCount:(NSInteger)n { [self.segCell setSegmentCount:n]; }
- (NSInteger)selectedSegment { return [self.segCell selectedSegment]; }
- (void)setSelectedSegment:(NSInteger)s { [self.segCell setSelectedSegment:s]; }
- (void)setLabel:(NSString *)label forSegment:(NSInteger)s { [self.segCell setLabel:label forSegment:s]; }
- (NSString *)labelForSegment:(NSInteger)s { return [self.segCell labelForSegment:s]; }
- (void)setWidth:(CGFloat)w forSegment:(NSInteger)s { [self.segCell setWidth:w forSegment:s]; }
- (CGFloat)widthForSegment:(NSInteger)s { return [self.segCell widthForSegment:s]; }

@end
