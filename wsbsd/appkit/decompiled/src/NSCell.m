/*
 * NSCell.m — 1:1 reimplementation of AppKit's NSCell (flag/state core).
 * Addresses cite the macOS 27 arm64e disassembly under ../evidence/nscell.
 *
 * The shipping NSCell keeps its booleans in a 64-bit _cFlags word at ivar
 * offset 0x10 (accessed as raw [self+0x10] in the disassembly). Decoded bits:
 *   bit 0    state on/off          (setState: 0x184f22888, state 0x184f22870)
 *   bit 1    highlighted           (isHighlighted 0x184f276bc)
 *   bit 2    disabled              (isEnabled 0x184f24de4: enabled == !(bit2))
 *   bits 4-5 cell type             (type 0x184f4cdfc)
 *   bit 52   state mixed           (setState: bfi #0x34; state checks the high bits)
 * We model _cFlags as a uint64_t and operate on the same bits.
 */
#import "NSCell.h"

enum : uint64_t {
    NSCellFlagStateOn     = 1ull << 0,
    NSCellFlagHighlighted = 1ull << 1,
    NSCellFlagDisabled    = 1ull << 2,
    NSCellFlagTypeShift   = 4,
    NSCellFlagTypeMask    = 0x3ull << 4,
    NSCellFlagEditable    = 1ull << 3,    /* isEditable  (0x18803c3d0 / bit 3) */
    NSCellFlagBordered    = 1ull << 8,    /* isBordered  (byte 0x11 bit 0) */
    NSCellFlagBezeled     = 1ull << 9,    /* isBezeled   (byte 0x11 bit 1) */
    NSCellFlagSelectable  = 1ull << 10,   /* isSelectable extra bit (0x408 = editable|selectable) */
    NSCellFlagStateMixed  = 1ull << 52,   /* bfi #0x34 */
};

@implementation NSCell {
    uint64_t _cFlags;   /* 0x10 */
}

/* -[NSCell state]  — evidence: 0x184f22870
 * mixed bit set -> NSControlStateValueMixed(-1); else bit0 -> On/Off. */
- (NSControlStateValue)state
{
    if (_cFlags & NSCellFlagStateMixed)
        return NSControlStateValueMixed;
    return (_cFlags & NSCellFlagStateOn) ? NSControlStateValueOn : NSControlStateValueOff;
}

/* -[NSCell setState:]  — evidence: 0x184f22888
 * mixed := (state < 0); on := (state != 0). (The real setter brackets this with
 * __cellCFlagsBitfieldLock and a "mixed allowed" gate at byte 0x16 bit 3 —
 * TODO(stage2): the gate and the lock.) */
- (void)setState:(NSControlStateValue)state
{
    if (state < 0)
        _cFlags |= NSCellFlagStateMixed;
    else
        _cFlags &= ~NSCellFlagStateMixed;

    if (state != 0)
        _cFlags |= NSCellFlagStateOn;
    else
        _cFlags &= ~NSCellFlagStateOn;
}

/* -[NSCell isEnabled]  — evidence: 0x184f24de4  (enabled == !(bit2)) */
- (BOOL)isEnabled { return (_cFlags & NSCellFlagDisabled) == 0; }

/* -[NSCell setEnabled:]  — evidence: 0x184f... (bit2 clear = enabled;
 * the real setter also redisplays and walks the control — TODO(stage2)). */
- (void)setEnabled:(BOOL)enabled
{
    if (enabled)
        _cFlags &= ~NSCellFlagDisabled;
    else
        _cFlags |= NSCellFlagDisabled;
}

/* -[NSCell isHighlighted]  — evidence: 0x184f276bc  (bit1) */
- (BOOL)isHighlighted { return (_cFlags & NSCellFlagHighlighted) != 0; }

- (void)setHighlighted:(BOOL)highlighted
{
    if (highlighted)
        _cFlags |= NSCellFlagHighlighted;
    else
        _cFlags &= ~NSCellFlagHighlighted;
}

/* -[NSCell type]  — evidence: 0x184f4cdfc  (bits 4-5) */
- (NSCellType)type { return (NSCellType)((_cFlags & NSCellFlagTypeMask) >> NSCellFlagTypeShift); }

/* Inverse of the decoded type getter (setType: body is stage2; this writes the
 * same two bits the getter reads). */
- (void)setType:(NSCellType)type
{
    _cFlags = (_cFlags & ~NSCellFlagTypeMask) | (((uint64_t)type << NSCellFlagTypeShift) & NSCellFlagTypeMask);
}

/* -[NSCell isBordered] 0x184f80fb0 (bit 8) / isBezeled 0x184f2e940 (bit 9).
 * A cell is bordered or bezeled, not both — setters clear the other, as the
 * shipping setBezeled: (0x184f2edc0) does. */
- (BOOL)isBordered { return (_cFlags & NSCellFlagBordered) != 0; }
- (void)setBordered:(BOOL)bordered
{
    if (bordered) _cFlags = (_cFlags | NSCellFlagBordered) & ~NSCellFlagBezeled;
    else          _cFlags &= ~NSCellFlagBordered;
}
- (BOOL)isBezeled { return (_cFlags & NSCellFlagBezeled) != 0; }
- (void)setBezeled:(BOOL)bezeled
{
    if (bezeled) _cFlags = (_cFlags | NSCellFlagBezeled) & ~NSCellFlagBordered;
    else         _cFlags &= ~NSCellFlagBezeled;
}

/* -[NSCell isEditable] 0x184f30410 (bit 3) / isSelectable 0x184fa571c (0x408). */
- (BOOL)isEditable { return (_cFlags & NSCellFlagEditable) != 0; }
- (void)setEditable:(BOOL)editable
{
    if (editable) _cFlags |= NSCellFlagEditable;           /* editable implies selectable */
    else          _cFlags &= ~NSCellFlagEditable;
}
- (BOOL)isSelectable { return (_cFlags & (NSCellFlagEditable | NSCellFlagSelectable)) != 0; }
- (void)setSelectable:(BOOL)selectable
{
    if (selectable) _cFlags |= NSCellFlagSelectable;
    else            _cFlags &= ~(NSCellFlagSelectable | NSCellFlagEditable);
}

#pragma mark - target/action/tag: NSCell stubs (real ones in NSActionCell)

- (id)target { return nil; }        /* evidence: 0x1851b0b10 */
- (SEL)action { return NULL; }      /* evidence: 0x1851b0b08 */
- (NSInteger)tag { return -1; }     /* evidence: 0x1855f893c */

/* setTarget:/setAction:/setTag: raise, verbatim messages — evidence: 0x1855f88fc / 0x1855f891c / 0x1855f8944 */
- (void)setTarget:(id)target
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Stub implementation of -setTarget by NSCell does nothing."];
}
- (void)setAction:(SEL)action
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Stub implementation of -setAction by NSCell does nothing."];
}
- (void)setTag:(NSInteger)tag
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Stub implementation of -setTag by NSCell does nothing."];
}

@end
