/*
 * NSSegmentedCell.m — 1:1 (core). Evidence ../evidence/seg:
 * segmentCount 0x184fb8898 (count of segments array @0x550), selectedSegment
 * 0x18504a93c, setSegmentCount: 0x184fb90cc (raises when count > 0x800).
 * Per-segment records are modelled as dictionaries (shipping packed records stage2).
 */
#import "NSSegmentedCell.h"

@implementation NSSegmentedCell {
    NSMutableArray<NSMutableDictionary *> *_segments;   /* @0x550 */
    NSInteger _selectedSegment;                         /* @0x548 */
}

- (instancetype)init
{
    self = [super init];
    if (self) { _segments = [NSMutableArray array]; _selectedSegment = -1; }
    return self;
}

- (NSInteger)segmentCount { return (NSInteger)_segments.count; }

- (void)setSegmentCount:(NSInteger)segmentCount
{
    if (segmentCount < 0 || segmentCount > 0x800)   /* binary: cmp #0x801 then raise */
        [NSException raise:NSInvalidArgumentException format:@"illegal segment count %ld", (long)segmentCount];
    while ((NSInteger)_segments.count < segmentCount)
        [_segments addObject:[@{@"label": @"", @"width": @0.0} mutableCopy]];
    while ((NSInteger)_segments.count > segmentCount)
        [_segments removeLastObject];
    if (_selectedSegment >= segmentCount) _selectedSegment = -1;
}

- (NSInteger)selectedSegment { return _selectedSegment; }
- (void)setSelectedSegment:(NSInteger)selectedSegment
{
    if (selectedSegment < -1 || selectedSegment >= (NSInteger)_segments.count) return;
    _selectedSegment = selectedSegment;
}

- (void)setLabel:(NSString *)label forSegment:(NSInteger)segment
{
    if (segment < 0 || segment >= (NSInteger)_segments.count) return;
    _segments[(NSUInteger)segment][@"label"] = [label copy] ?: @"";
}
- (NSString *)labelForSegment:(NSInteger)segment
{
    if (segment < 0 || segment >= (NSInteger)_segments.count) return nil;
    return _segments[(NSUInteger)segment][@"label"];
}

- (void)setWidth:(CGFloat)width forSegment:(NSInteger)segment
{
    if (segment < 0 || segment >= (NSInteger)_segments.count) return;
    _segments[(NSUInteger)segment][@"width"] = @(width);
}
- (CGFloat)widthForSegment:(NSInteger)segment
{
    if (segment < 0 || segment >= (NSInteger)_segments.count) return 0.0;
    return [_segments[(NSUInteger)segment][@"width"] doubleValue];
}

@end
