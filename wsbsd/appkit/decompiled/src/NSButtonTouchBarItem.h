/*
 * NSButtonTouchBarItem.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSButtonTouchBarItem (: NSTouchBarItem), a Touch Bar item showing a button.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSButtonTouchBarItem_interface.txt. Real ivars: _button, _image,
 * _target, _action, _customizationLabel.
 *
 * Measured on this Mac: default title "", enabled YES, image/bezelColor nil.
 * This core reproduces the item's value model + convenience constructors. The
 * backing NSButton view (-view) is lazily built = TODO(stage2).
 */

#import "NSTouchBarItem.h"

NS_ASSUME_NONNULL_BEGIN

@class NSImage, NSColor;

@interface NSButtonTouchBarItem : NSTouchBarItem

+ (instancetype)buttonTouchBarItemWithIdentifier:(NSString *)identifier title:(nullable NSString *)title target:(nullable id)target action:(nullable SEL)action;
+ (instancetype)buttonTouchBarItemWithIdentifier:(NSString *)identifier image:(nullable NSImage *)image target:(nullable id)target action:(nullable SEL)action;
+ (instancetype)buttonTouchBarItemWithIdentifier:(NSString *)identifier title:(nullable NSString *)title image:(nullable NSImage *)image target:(nullable id)target action:(nullable SEL)action;

@property (copy) NSString *title;                  /* default "" */
@property (nullable, strong) NSImage *image;
@property (nullable, copy) NSColor *bezelColor;
@property (nullable, weak) id target;
@property SEL action;
@property (getter=isEnabled) BOOL enabled;         /* default YES */
@property (copy) NSString *customizationLabel;

@end

NS_ASSUME_NONNULL_END
