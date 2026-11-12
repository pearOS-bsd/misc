/*
 * NSColorPicker.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSColorPicker, the abstract base for NSColorPanel picker plug-ins.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSColorPicker_interface.txt. Real ivars: _imageObject,
 * _buttonToolTip, _colorPanel. It adopts NSColorPickingDefault.
 *
 * This core reproduces the base adapter: initWithPickerMask:colorPanel: stores
 * the panel and the mode mask; -colorPanel returns the panel; -buttonToolTip
 * defaults to the class name (measured "NSColorPicker"); -setMode: and the
 * attach/detach/alpha/viewSize hooks are no-ops the base provides for subclasses
 * to override. -provideNewView:, -provideNewButtonImage and -minContentSize are
 * the subclass's responsibility (the raw base throws) — TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class NSColorPanel, NSColorList, NSImage;

typedef NS_OPTIONS(NSUInteger, NSColorPanelOptions) { NSColorPanelOptionsAll = 0xffff };
typedef NSInteger NSColorPanelMode;

@interface NSColorPicker : NSObject

- (instancetype)initWithPickerMask:(NSUInteger)mask colorPanel:(NSColorPanel *)owningColorPanel;

@property (readonly, strong) NSColorPanel *colorPanel;
@property (readonly, nullable) NSImage *provideNewButtonImage;
@property (readonly, copy) NSString *buttonToolTip;
@property (readonly) CGSize minContentSize;

- (void)setMode:(NSColorPanelMode)mode;
- (void)attachColorList:(nullable NSColorList *)colorList;
- (void)detachColorList:(nullable NSColorList *)colorList;
- (void)alphaControlAddedOrRemoved:(nullable id)sender;
- (void)viewSizeChanged:(nullable id)sender;

/* exposed for subclasses/tests: the mode last set and the picker mask. */
@property (readonly) NSColorPanelMode currentMode;
@property (readonly) NSUInteger pickerMask;

@end

NS_ASSUME_NONNULL_END
