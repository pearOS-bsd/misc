/*
 * NSColorPickerTouchBarItem.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSColorPickerTouchBarItem (: NSTouchBarItem), a Touch Bar colour well/picker.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSColorPickerTouchBarItem_interface.txt.
 *
 * Measured on this Mac: showsAlpha default YES, enabled YES, default colour
 * black, allowedColorSpaces empty. This core reproduces the colour/config value
 * model + convenience constructors. The popover presentation, the colour-picker
 * view-controller delegate callbacks and the semantic default colour are
 * TODO(stage2).
 */

#import "NSTouchBarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSColor, NSColorList, NSImage;

@interface NSColorPickerTouchBarItem : NSTouchBarItem

+ (instancetype)colorPickerWithIdentifier:(NSString *)identifier;
+ (instancetype)colorPickerWithIdentifier:(NSString *)identifier buttonImage:(NSImage *)image;
+ (instancetype)colorPickerWithIdentifier:(NSString *)identifier buttonTitle:(NSString *)title;
+ (instancetype)strokeColorPickerWithIdentifier:(NSString *)identifier;
+ (instancetype)textColorPickerWithIdentifier:(NSString *)identifier;

@property (nullable, strong) NSColor *color;
@property BOOL showsAlpha;                        /* default YES */
@property (nullable, strong) NSColorList *colorList;
@property (nullable, copy) NSArray *allowedColorSpaces;
@property BOOL colorListSupportsPressAndHoldVariants;
@property (nullable, copy) NSString *buttonTitle;
@property (nullable, strong) NSImage *buttonImage;
@property (nullable, weak) id target;
@property SEL action;
@property (getter=isEnabled) BOOL enabled;        /* default YES */
@property (copy) NSString *customizationLabel;

@end

NS_ASSUME_NONNULL_END
