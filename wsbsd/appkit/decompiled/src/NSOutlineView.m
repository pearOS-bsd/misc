/*
 * NSOutlineView.m — 1:1 (core). Evidence ../evidence/outline:
 * indentationPerLevel 0x184f8dd90 (integer ivar -> scvtf to double),
 * setIndentationPerLevel: 0x184f6ec74 (fcvtas then bic to clamp >= 0),
 * outlineTableColumn 0x18519f34c, autoresizesOutlineColumn 0x185145b00 (flags bit 3).
 */
#import "NSOutlineView.h"
#import <math.h>

@implementation NSOutlineView {
    NSInteger _indentationPerLevel;      /* stored as integer */
    NSTableColumn *_outlineTableColumn;
    uint64_t _olFlags;                   /* autoresizesOutlineColumn = bit 3 */
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) { _indentationPerLevel = 16; _olFlags |= 0x8; }  /* defaults: 16, autoresize YES */
    return self;
}

/* integer storage, double accessor (scvtf). */
- (CGFloat)indentationPerLevel { return (CGFloat)_indentationPerLevel; }
- (void)setIndentationPerLevel:(CGFloat)indentationPerLevel
{
    NSInteger v = (NSInteger)indentationPerLevel;   /* fcvtas: truncate toward nearest */
    if (v < 0) v = 0;                               /* bic ...asr#63: clamp >= 0 */
    _indentationPerLevel = v;
}

- (NSTableColumn *)outlineTableColumn { return _outlineTableColumn; }
- (void)setOutlineTableColumn:(NSTableColumn *)outlineTableColumn { _outlineTableColumn = outlineTableColumn; }

- (BOOL)autoresizesOutlineColumn { return (_olFlags >> 3) & 1u; }
- (void)setAutoresizesOutlineColumn:(BOOL)v
{
    if (v) _olFlags |= 0x8;
    else   _olFlags &= ~0x8ull;
}

@end
