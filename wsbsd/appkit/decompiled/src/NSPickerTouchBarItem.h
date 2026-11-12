/*
 * NSPickerTouchBarItem.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSPickerTouchBarItem (: NSTouchBarItem), a segmented picker in the Touch Bar.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPickerTouchBarItem_interface.txt.
 *
 * Measured on this Mac: a labels factory gives numberOfOptions=count,
 * selectedIndex=-1, selectionMode SelectOne(0), controlRepresentation
 * Automatic(0), enabled YES; a bare init gives 0 options. This core reproduces
 * the per-option label/image/enabled model + selection + factories. The backing
 * picker view (-view) is TODO(stage2).
 */

#import "NSTouchBarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSImage, NSColor;

typedef NS_ENUM(NSInteger, NSPickerTouchBarItemSelectionMode) {
    NSPickerTouchBarItemSelectionModeSelectOne = 0,
    NSPickerTouchBarItemSelectionModeSelectAny = 1,
    NSPickerTouchBarItemSelectionModeMomentary = 2,
};

typedef NS_ENUM(NSInteger, NSPickerTouchBarItemControlRepresentation) {
    NSPickerTouchBarItemControlRepresentationAutomatic = 0,
    NSPickerTouchBarItemControlRepresentationExpanded  = 1,
    NSPickerTouchBarItemControlRepresentationCollapsed = 2,
};

@interface NSPickerTouchBarItem : NSTouchBarItem

+ (instancetype)pickerTouchBarItemWithIdentifier:(NSString *)identifier labels:(NSArray<NSString *> *)labels selectionMode:(NSPickerTouchBarItemSelectionMode)selectionMode target:(nullable id)target action:(nullable SEL)action;
+ (instancetype)pickerTouchBarItemWithIdentifier:(NSString *)identifier images:(NSArray<NSImage *> *)images selectionMode:(NSPickerTouchBarItemSelectionMode)selectionMode target:(nullable id)target action:(nullable SEL)action;

@property (readonly) NSInteger numberOfOptions;
- (void)setNumberOfOptions:(NSInteger)numberOfOptions;   /* grows/shrinks the per-option arrays */
@property NSInteger selectedIndex;                       /* default -1 */
@property NSPickerTouchBarItemSelectionMode selectionMode;
@property NSPickerTouchBarItemControlRepresentation controlRepresentation;
@property (nullable, copy) NSString *collapsedRepresentationLabel;
@property (nullable, strong) NSImage *collapsedRepresentationImage;
@property (nullable, copy) NSColor *selectionColor;
@property (nullable, weak) id target;
@property SEL action;
@property (getter=isEnabled) BOOL enabled;
@property (copy) NSString *customizationLabel;

- (nullable NSString *)labelAtIndex:(NSInteger)index;
- (void)setLabel:(nullable NSString *)label atIndex:(NSInteger)index;
- (nullable NSImage *)imageAtIndex:(NSInteger)index;
- (void)setImage:(nullable NSImage *)image atIndex:(NSInteger)index;
- (BOOL)isEnabledAtIndex:(NSInteger)index;
- (void)setEnabled:(BOOL)enabled atIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
