/*
 * NSComboButton.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSComboButton (: NSControl), the macOS 13+ push button with a pull-down menu.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSComboButton_interface.txt. Real ivars: _style, _menu, _title,
 * _image, _imageScaling, _segmentedControl.
 *
 * Defaults MEASURED on this Mac: title "" (null_resettable), style Split(0),
 * imageScaling 0, image nil; the convenience constructors set title/image/menu/
 * target/action. The internal NSSegmentedControl, intrinsic-content-size layout
 * and the arrow-triggered menu presentation are TODO(stage2).
 */

#import "NSControl.h"

NS_ASSUME_NONNULL_BEGIN

@class NSMenu, NSImage;

typedef NS_ENUM(NSInteger, NSComboButtonStyle) {
    NSComboButtonStyleSplit   = 0,
    NSComboButtonStyleUnified = 1,
};

/* NSImageScaling lives in NSImageCell.h on macOS; mirror it here (guarded) so
 * this header does not require NSImageCell. */
#ifndef NSImageScaling_defined
#define NSImageScaling_defined
typedef NS_ENUM(NSUInteger, NSImageScaling) {
    NSImageScaleProportionallyDown     = 0,
    NSImageScaleAxesIndependently      = 1,
    NSImageScaleNone                   = 2,
    NSImageScaleProportionallyUpOrDown = 3,
};
#endif

@interface NSComboButton : NSControl

+ (instancetype)comboButtonWithTitle:(NSString *)title menu:(NSMenu *)menu target:(nullable id)target action:(nullable SEL)action;
+ (instancetype)comboButtonWithImage:(NSImage *)image menu:(NSMenu *)menu target:(nullable id)target action:(nullable SEL)action;
+ (instancetype)comboButtonWithTitle:(NSString *)title image:(nullable NSImage *)image menu:(NSMenu *)menu target:(nullable id)target action:(nullable SEL)action;

@property (copy) NSString *title;                /* null_resettable -> "" */
@property (nullable, strong) NSImage *image;
@property NSImageScaling imageScaling;           /* default 0 */
@property (nullable, strong) NSMenu *menu;
@property NSComboButtonStyle style;              /* default Split */

@end

NS_ASSUME_NONNULL_END
