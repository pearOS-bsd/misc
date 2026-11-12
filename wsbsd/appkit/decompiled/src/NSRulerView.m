/*
 * NSRulerView.m — behavioral-1:1 core. See the header.
 */

#import "NSRulerView.h"

@implementation NSRulerView {
    __weak NSScrollView *_scrollView;
    NSRulerOrientation _orientation;
    CGFloat _ruleThickness;
    CGFloat _reservedThicknessForMarkers;
    CGFloat _reservedThicknessForAccessoryView;
    CGFloat _originOffset;
    NSString *_measurementUnits;
    __weak NSView *_clientView;
    NSView *_accessoryView;
    NSMutableArray<NSRulerMarker *> *_markers;
}

- (instancetype)initWithScrollView:(NSScrollView *)scrollView orientation:(NSRulerOrientation)orientation
{
    self = [super initWithFrame:CGRectZero];
    if (self) {
        _scrollView = scrollView;
        _orientation = orientation;
        _ruleThickness = 17.0;                      /* measured */
        _reservedThicknessForMarkers = 15.0;        /* measured */
        _reservedThicknessForAccessoryView = 0.0;   /* measured */
        _originOffset = 0.0;                         /* measured */
        _measurementUnits = @"Centimeters";          /* measured (locale-derived; stage2 for full locale mapping) */
    }
    return self;
}

- (NSScrollView *)scrollView { return _scrollView; }
- (void)setScrollView:(NSScrollView *)v { _scrollView = v; }
- (NSRulerOrientation)orientation { return _orientation; }
- (void)setOrientation:(NSRulerOrientation)o { _orientation = o; }
- (CGFloat)ruleThickness { return _ruleThickness; }
- (void)setRuleThickness:(CGFloat)v { _ruleThickness = v; }
- (CGFloat)reservedThicknessForMarkers { return _reservedThicknessForMarkers; }
- (void)setReservedThicknessForMarkers:(CGFloat)v { _reservedThicknessForMarkers = v; }
- (CGFloat)reservedThicknessForAccessoryView { return _reservedThicknessForAccessoryView; }
- (void)setReservedThicknessForAccessoryView:(CGFloat)v { _reservedThicknessForAccessoryView = v; }
- (CGFloat)originOffset { return _originOffset; }
- (void)setOriginOffset:(CGFloat)v { _originOffset = v; }
- (NSString *)measurementUnits { return _measurementUnits; }
- (void)setMeasurementUnits:(NSString *)u { _measurementUnits = [u copy]; }
- (NSView *)clientView { return _clientView; }
- (void)setClientView:(NSView *)v { _clientView = v; }
- (NSView *)accessoryView { return _accessoryView; }
- (void)setAccessoryView:(NSView *)v { _accessoryView = v; }
- (NSArray<NSRulerMarker *> *)markers { return _markers.count ? [_markers copy] : nil; }
- (void)setMarkers:(NSArray<NSRulerMarker *> *)m { _markers = [m mutableCopy]; }
- (CGFloat)baselineLocation { return 0.0; }   /* derived from layout = stage2 */

- (CGFloat)requiredThickness
{
    /* measured: the three reserved bands stack. */
    return _ruleThickness + _reservedThicknessForMarkers + _reservedThicknessForAccessoryView;
}

- (void)addMarker:(NSRulerMarker *)marker
{
    if (!marker) return;
    if (!_markers) _markers = [NSMutableArray array];
    if (![_markers containsObject:marker]) [_markers addObject:marker];
}

- (void)removeMarker:(NSRulerMarker *)marker { [_markers removeObject:marker]; }

@end
