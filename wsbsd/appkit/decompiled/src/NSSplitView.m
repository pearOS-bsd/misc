/*
 * NSSplitView.m — 1:1 (core). Evidence ../evidence/split:
 * isVertical 0x184f5ad04 (flags bit 0x40000), setVertical: 0x184f5a928 (same bit),
 * dividerStyle 0x184fa93f8 (ivar 0x9e0). dividerThickness 0x184faac98 is derived
 * from the style via a helper (exact pt values stage2).
 */
#import "NSSplitView.h"

enum : uint64_t { NSSplitViewFlagVertical = 0x40000 };   /* bit 18 */

@implementation NSSplitView {
    uint64_t _sFlags;
    NSSplitViewDividerStyle _dividerStyle;   /* 0x9e0 */
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) _dividerStyle = NSSplitViewDividerStyleThin;   /* conventional default */
    return self;
}

- (BOOL)isVertical { return (_sFlags & NSSplitViewFlagVertical) != 0; }
- (void)setVertical:(BOOL)vertical
{
    if (vertical) _sFlags |= NSSplitViewFlagVertical;
    else          _sFlags &= ~NSSplitViewFlagVertical;
}

- (NSSplitViewDividerStyle)dividerStyle { return _dividerStyle; }
- (void)setDividerStyle:(NSSplitViewDividerStyle)dividerStyle { _dividerStyle = dividerStyle; }

/* derived from the style (exact values from the shipping helper are stage2). */
- (CGFloat)dividerThickness
{
    return (_dividerStyle == NSSplitViewDividerStyleThin) ? 1.0 : 10.0;
}

@end
