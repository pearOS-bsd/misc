/*
 * NSButtonCell.m — 1:1 reimplementation of AppKit's NSButtonCell (core).
 * Addresses cite the macOS 27 arm64e disassembly under ../evidence/button.
 *
 * title    — evidence 0x184f4a81c: [self+0x8] (_contents) -> _NSButtonTitleFromContents.
 *            setTitle: 0x184f22a94 -> _NSButtonSetAttributedOrPlainTitle(self, title, 1).
 *            The _contents object + title-from-contents conversion is stage2; we
 *            keep the plain title in an ivar so the contract (round-trip) holds.
 * bezelStyle — evidence 0x184f2385c / setBezelStyle: 0x184f494b4: a dedicated
 *            ivar (offset held at 0x1e63e2000+0x1e0); setter refreshes contents.
 * setButtonType: — evidence 0x184f4c27c -> helper 0x18805f1a0 programs the
 *            highlightsBy/showsStateBy masks per type. Mask programming is stage2.
 */
#import "NSButtonCell.h"

@implementation NSButtonCell {
    NSString *_title;         /* shipping: via _contents (stage2) */
    NSBezelStyle _bezelStyle; /* dedicated ivar in the binary */
    NSButtonType _buttonType; /* shipping: encoded as highlight/showsState masks (stage2) */
}

- (NSString *)title { return _title ?: @""; }
- (void)setTitle:(NSString *)title { _title = [title copy]; }

- (NSBezelStyle)bezelStyle { return _bezelStyle; }
- (void)setBezelStyle:(NSBezelStyle)bezelStyle
{
    if (_bezelStyle == bezelStyle)
        return;                 /* early-out, as the binary does */
    _bezelStyle = bezelStyle;
    /* TODO(stage2): refresh _contents for the new bezel (helper 0x18807c5b0). */
}

- (void)setButtonType:(NSButtonType)type
{
    _buttonType = type;
    /* TODO(stage2): program highlightsBy/showsStateBy masks via 0x18805f1a0. */
}

@end
