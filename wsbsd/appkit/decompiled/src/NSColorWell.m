/*
 * NSColorWell.m — 1:1 (core). Evidence ../evidence/cwell:
 * color 0x18520e5b4 ([self+0x728]), isActive 0x185157700 (_cwFlags bit 0),
 * isBordered 0x1856020e8 (_cwFlags bit 1), setBordered: 0x185157144.
 * activate:/deactivate drive the shared NSColorPanel (stage2).
 */
#import "NSColorWell.h"

enum : uint8_t { NSColorWellFlagActive = 0x1, NSColorWellFlagBordered = 0x2 };

@implementation NSColorWell {
    id _color;            /* 0x728 */
    uint8_t _cwFlags;     /* 0x724 */
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) _cwFlags |= NSColorWellFlagBordered;   /* bordered by default */
    return self;
}

- (id)color { return _color; }
- (void)setColor:(id)color { _color = color; }

- (BOOL)isActive { return (_cwFlags & NSColorWellFlagActive) != 0; }

- (BOOL)isBordered { return (_cwFlags & NSColorWellFlagBordered) != 0; }
- (void)setBordered:(BOOL)bordered
{
    if (bordered) _cwFlags |= NSColorWellFlagBordered;
    else          _cwFlags &= ~NSColorWellFlagBordered;
}

/* activate:/deactivate flip the active bit; the shared NSColorPanel show/hide
 * and the exclusive-deactivation of other wells are stage2. */
- (void)activate:(BOOL)exclusive { _cwFlags |= NSColorWellFlagActive; }
- (void)deactivate { _cwFlags &= ~NSColorWellFlagActive; }

@end
