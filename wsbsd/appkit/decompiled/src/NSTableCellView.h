/*
 * NSTableCellView.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSTableCellView (: NSView), the standard view-based table/outline cell.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSTableCellView_interface.txt. Real ivars: _textField, _imageView,
 * _objectValue, _tintConfiguration, _rowSizeStyle, _backgroundStyle and a packed
 * _cellFlags (doingLayout/isGroupRow/isSourceList/followsKeyState).
 *
 * Defaults MEASURED on this Mac: backgroundStyle=Normal(0), rowSizeStyle=Custom(0),
 * objectValue/textField/imageView nil, draggingImageComponents has one element
 * (the view-snapshot fallback).
 *
 * This core reproduces the outlet/value model and the drag-component count. The
 * actual IB-connected subviews, backgroundStyle propagation to the subview cells,
 * baseline/auto-layout and real drag-image compositing are TODO(stage2).
 */

#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTextField, NSImageView, NSTintConfiguration, NSDraggingImageComponent;

typedef NS_ENUM(NSInteger, NSBackgroundStyle) {
    NSBackgroundStyleNormal     = 0,
    NSBackgroundStyleEmphasized = 1,
    NSBackgroundStyleRaised     = 2,
    NSBackgroundStyleLowered    = 3,
};

typedef NS_ENUM(NSInteger, NSTableViewRowSizeStyle) {
    NSTableViewRowSizeStyleDefault = -1,
    NSTableViewRowSizeStyleCustom  = 0,
    NSTableViewRowSizeStyleSmall   = 1,
    NSTableViewRowSizeStyleMedium  = 2,
    NSTableViewRowSizeStyleLarge   = 3,
};

@interface NSTableCellView : NSView

@property (nullable, strong) id objectValue;
@property (nullable, strong) NSTextField *textField;
@property (nullable, strong) NSImageView *imageView;
@property NSBackgroundStyle backgroundStyle;            /* default Normal */
@property NSTableViewRowSizeStyle rowSizeStyle;         /* default Custom */
@property (nullable, strong) NSTintConfiguration *tintConfiguration;
@property (readonly, copy) NSArray<NSDraggingImageComponent *> *draggingImageComponents;

@end

NS_ASSUME_NONNULL_END
