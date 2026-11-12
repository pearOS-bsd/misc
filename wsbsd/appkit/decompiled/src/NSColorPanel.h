/*
 * NSColorPanel.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSColorPanel, the shared system color picker panel.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSColorPanel_interface.txt.
 *
 * NSColorPanel is an NSPanel (measured). This core reproduces the shared
 * singleton and the picker state: color (non-nil default), mode (Wheel default),
 * showsAlpha (YES), continuous (YES), accessoryView, target/action (a continuous
 * color change fires the action). The picker UI, color-list attachment and
 * +setPickerMode:/+setPickerMask: visual effects are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSPanel.h"

NS_ASSUME_NONNULL_BEGIN

#ifndef NSColorPanelMode_ENUM_DEFINED
#define NSColorPanelMode_ENUM_DEFINED
typedef NS_ENUM(NSInteger, NSColorPanelModeValue) {
    NSColorPanelModeNone = -1,
    NSColorPanelModeGray = 0,
    NSColorPanelModeRGB = 1,
    NSColorPanelModeCMYK = 2,
    NSColorPanelModeHSB = 3,
    NSColorPanelModeCustomPalette = 4,
    NSColorPanelModeColorList = 5,
    NSColorPanelModeWheel = 6,
    NSColorPanelModeCrayon = 7,
};
#endif

@class NSColor, NSView, NSColorList;

@interface NSColorPanel : NSPanel

@property (class, readonly, strong) NSColorPanel *sharedColorPanel;
@property (class, readonly) BOOL sharedColorPanelExists;

@property (copy) NSColor *color;
@property NSInteger mode;
@property BOOL showsAlpha;
@property (getter=isContinuous) BOOL continuous;
@property (nullable, strong) NSView *accessoryView;

- (void)setTarget:(nullable id)target;
- (void)setAction:(nullable SEL)action;
- (void)attachColorList:(NSColorList *)colorList;
- (void)detachColorList:(NSColorList *)colorList;

@end

NS_ASSUME_NONNULL_END
