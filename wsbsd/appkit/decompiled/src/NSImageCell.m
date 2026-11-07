/*
 * NSImageCell.m — 1:1 reimplementation (core).
 * Evidence ../evidence/image: imageScaling = flags bits 26-28 (ubfx #0x1a,#3,
 * 0x184fba854), imageAlignment = bits 22-25 (ubfx #0x16,#4, 0x185079dc0),
 * imageFrameStyle = bits 29-31 (lsr #0x1d, 0x184fba8f4). One uint32 flags word.
 */
#import "NSImageCell.h"

enum : uint32_t {
    NSImageCellAlignShift = 22, NSImageCellAlignMask = 0xFu << 22,
    NSImageCellScaleShift = 26, NSImageCellScaleMask = 0x7u << 26,
    NSImageCellFrameShift = 29, NSImageCellFrameMask = 0x7u << 29,
};

@implementation NSImageCell {
    uint32_t _icFlags;
    id _image;
}

- (NSImageAlignment)imageAlignment { return (NSImageAlignment)((_icFlags & NSImageCellAlignMask) >> NSImageCellAlignShift); }
- (void)setImageAlignment:(NSImageAlignment)a
{ _icFlags = (_icFlags & ~NSImageCellAlignMask) | (((uint32_t)a << NSImageCellAlignShift) & NSImageCellAlignMask); }

- (NSImageScaling)imageScaling { return (NSImageScaling)((_icFlags & NSImageCellScaleMask) >> NSImageCellScaleShift); }
- (void)setImageScaling:(NSImageScaling)s
{ _icFlags = (_icFlags & ~NSImageCellScaleMask) | (((uint32_t)s << NSImageCellScaleShift) & NSImageCellScaleMask); }

- (NSImageFrameStyle)imageFrameStyle { return (NSImageFrameStyle)((_icFlags & NSImageCellFrameMask) >> NSImageCellFrameShift); }
- (void)setImageFrameStyle:(NSImageFrameStyle)f
{ _icFlags = (_icFlags & ~NSImageCellFrameMask) | (((uint32_t)f << NSImageCellFrameShift) & NSImageCellFrameMask); }

- (id)image { return _image; }
- (void)setImage:(id)image { _image = image; }

@end
