/*
 * NSVisualEffectView.m — 1:1 (core). Evidence ../evidence/vev:
 * material 0x184f34dc4 ([self+0x140], setter early-out if equal), isEmphasized
 * 0x184ff6894 (_emphasized @0x144 bit 1), state 0x184f1cc7c ([self+0x148]),
 * blendingMode 0x184f1cc68 ([self+0x14c]).
 */
#import "NSVisualEffectView.h"

@implementation NSVisualEffectView {
    NSInteger _material;        /* 0x140 */
    uint8_t _emphasized;        /* 0x144 (bit 1) */
    NSInteger _state;           /* 0x148 */
    NSInteger _blendingMode;    /* 0x14c */
}

- (NSVisualEffectMaterial)material { return (NSVisualEffectMaterial)_material; }
- (void)setMaterial:(NSVisualEffectMaterial)material
{
    if (_material == material) return;   /* early-out as the binary does */
    _material = material;
}

- (NSVisualEffectBlendingMode)blendingMode { return (NSVisualEffectBlendingMode)_blendingMode; }
- (void)setBlendingMode:(NSVisualEffectBlendingMode)blendingMode { _blendingMode = blendingMode; }

- (NSVisualEffectState)state { return (NSVisualEffectState)_state; }
- (void)setState:(NSVisualEffectState)state { _state = state; }

- (BOOL)isEmphasized { return (_emphasized >> 1) & 1u; }
- (void)setEmphasized:(BOOL)emphasized
{
    if (emphasized) _emphasized |= 0x2;
    else            _emphasized &= ~0x2;
}

@end
