/*
 * NSPathComponentCell.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSPathComponentCell (: NSTextFieldCell), one component of an NSPathControl /
 * NSPathCell path.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSPathComponentCell_interface.txt. Real ivars: _image, _url,
 * widths (_minWidth/_fullWidth/_resizedWidth/_currentWidth) and a _flags
 * bitfield (shouldDrawArrow / drawsAsNavigationBar / first/last item / drop target).
 *
 * This core reproduces the component's own value model — image and URL, plus the
 * inherited title via -stringValue — and NSCopying. The drawing/geometry
 * (drawInteriorWithFrame:/imageRectForBounds:/titleRectForBounds:/cellSizeForBounds:,
 * navigation-bar arrow + width layout) is TODO(stage2).
 */

#import "NSTextFieldCell.h"

NS_ASSUME_NONNULL_BEGIN

@class NSImage;

@interface NSPathComponentCell : NSTextFieldCell

@property (nullable, strong) NSImage *image;
@property (nullable, copy) NSURL *URL;

@end

NS_ASSUME_NONNULL_END
