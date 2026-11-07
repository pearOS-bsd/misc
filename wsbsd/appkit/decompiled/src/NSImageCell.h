/*
 * NSImageCell.h — 1:1 reimplementation of AppKit's NSImageCell (core).
 * NSCell subclass. Evidence ../evidence/image: a packed flags word holds
 * imageAlignment (bits 22-25), imageScaling (bits 26-28), imageFrameStyle
 * (bits 29-31). The image itself is an NSImage (class cluster) → stage2.
 */
#import "NSCell.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSImageAlignment) {
    NSImageAlignCenter = 0, NSImageAlignTop, NSImageAlignTopLeft, NSImageAlignTopRight,
    NSImageAlignLeft, NSImageAlignBottom, NSImageAlignBottomLeft, NSImageAlignBottomRight,
    NSImageAlignRight,
};
typedef NS_ENUM(NSUInteger, NSImageFrameStyle) {
    NSImageFrameNone = 0, NSImageFramePhoto, NSImageFrameGrayBezel, NSImageFrameGroove, NSImageFrameButton,
};
typedef NS_ENUM(NSUInteger, NSImageScaling) {
    NSImageScaleProportionallyDown = 0, NSImageScaleAxesIndependently,
    NSImageScaleNone, NSImageScaleProportionallyUpOrDown,
};

@interface NSImageCell : NSCell
@property NSImageAlignment imageAlignment;
@property NSImageScaling imageScaling;
@property NSImageFrameStyle imageFrameStyle;
@property (nullable, strong) id image;   /* NSImage (cluster) — stage2 */
@end

NS_ASSUME_NONNULL_END
