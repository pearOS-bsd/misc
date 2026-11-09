/*
 * NSPanel.m — 1:1 (core). Evidence ../evidence/panel:
 * isFloatingPanel 0x18521ab48 (_wFlags bit 22), becomesKeyOnlyIfNeeded
 * 0x185166a94 (_wFlags bit 15), worksWhenModal 0x185162518 (_wFlags bit 14).
 * Kept in a local flag word here (shipping uses the inherited NSWindow _wFlags).
 */
#import "NSPanel.h"

enum : uint32_t {
    NSPanelFlagFloating = 1u << 22,
    NSPanelFlagBecomesKeyOnlyIfNeeded = 1u << 15,
    NSPanelFlagWorksWhenModal = 1u << 14,
};

@implementation NSPanel {
    uint32_t _panelFlags;
}

- (BOOL)isFloatingPanel { return (_panelFlags & NSPanelFlagFloating) != 0; }
- (void)setFloatingPanel:(BOOL)v
{ if (v) _panelFlags |= NSPanelFlagFloating; else _panelFlags &= ~NSPanelFlagFloating; }

- (BOOL)becomesKeyOnlyIfNeeded { return (_panelFlags & NSPanelFlagBecomesKeyOnlyIfNeeded) != 0; }
- (void)setBecomesKeyOnlyIfNeeded:(BOOL)v
{ if (v) _panelFlags |= NSPanelFlagBecomesKeyOnlyIfNeeded; else _panelFlags &= ~NSPanelFlagBecomesKeyOnlyIfNeeded; }

- (BOOL)worksWhenModal { return (_panelFlags & NSPanelFlagWorksWhenModal) != 0; }
- (void)setWorksWhenModal:(BOOL)v
{ if (v) _panelFlags |= NSPanelFlagWorksWhenModal; else _panelFlags &= ~NSPanelFlagWorksWhenModal; }

@end
