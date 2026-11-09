/*
 * NSVisualEffectView.h — 1:1 reimplementation (core). NSView subclass.
 * Evidence ../evidence/vev: _material @0x140, _emphasized @0x144 (bit 1),
 * _state @0x148, _blendingMode @0x14c — all direct ivars. The actual blur /
 * backdrop rendering is the project's liquid-glass layer (stage2 here).
 */
#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSVisualEffectMaterial) {
    NSVisualEffectMaterialTitlebar = 3,
    NSVisualEffectMaterialMenu = 4,
    NSVisualEffectMaterialPopover = 6,
    NSVisualEffectMaterialSidebar = 7,
    NSVisualEffectMaterialHUDWindow = 13,
    NSVisualEffectMaterialUnderWindowBackground = 21,
};
typedef NS_ENUM(NSInteger, NSVisualEffectBlendingMode) {
    NSVisualEffectBlendingModeBehindWindow = 0,
    NSVisualEffectBlendingModeWithinWindow = 1,
};
typedef NS_ENUM(NSInteger, NSVisualEffectState) {
    NSVisualEffectStateFollowsWindowActiveState = 0,
    NSVisualEffectStateActive = 1,
    NSVisualEffectStateInactive = 2,
};

@interface NSVisualEffectView : NSView
@property NSVisualEffectMaterial material;
@property NSVisualEffectBlendingMode blendingMode;
@property NSVisualEffectState state;
@property (getter=isEmphasized) BOOL emphasized;
@end

NS_ASSUME_NONNULL_END
