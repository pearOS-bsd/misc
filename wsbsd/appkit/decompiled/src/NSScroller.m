/*
 * NSScroller.m — 1:1 (core). Evidence ../evidence/scroller:
 * knobProportion 0x184f60788 ([self+0x8a8]), doubleValue 0x184f60664
 * ([self+0x88c]); the setters clamp to [0,1]. scrollerStyle 0x184f5f9d8
 * (_sFlags2 @0x54c bit 9).
 */
#import "NSScroller.h"

@implementation NSScroller {
    double _knobProportion;   /* 0x8a8 */
    double _doubleValue;      /* 0x88c */
    uint32_t _sFlags2;        /* 0x54c (scrollerStyle bit 9) */
}

static inline double NSScrollerClamp01(double v) { return v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v); }

- (CGFloat)knobProportion { return _knobProportion; }
- (void)setKnobProportion:(CGFloat)knobProportion { _knobProportion = NSScrollerClamp01(knobProportion); }

- (double)doubleValue { return _doubleValue; }
- (void)setDoubleValue:(double)doubleValue { _doubleValue = NSScrollerClamp01(doubleValue); }

- (NSScrollerStyle)scrollerStyle { return (NSScrollerStyle)((_sFlags2 >> 9) & 0x1u); }
- (void)setScrollerStyle:(NSScrollerStyle)scrollerStyle
{
    if (scrollerStyle) _sFlags2 |= (1u << 9);
    else               _sFlags2 &= ~(1u << 9);
}

@end
