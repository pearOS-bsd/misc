/*
 * NSBox.m — 1:1 reimplementation of AppKit's NSBox (core).
 * Addresses cite the macOS 27 arm64e disassembly under ../evidence/box.
 *
 * _bFlags (uint32 @0x91c) bit layout:
 *   bits 0-1   borderType     (borderType 0x1850dd3ac: & 0x3)
 *   bits 2-4   titlePosition  (titlePosition 0x185093dbc: ubfx #2,#3)
 *   bit  9     isTransparent  (isTransparent 0x18502c734: byte[1] bit 1)
 *   bits 10-12 boxType        (boxType 0x18502c5c4: ubfx #0xa,#3)
 */
#import "NSBox.h"

@implementation NSBox {
    uint32_t _bFlags;       /* 0x91c */
    NSString *_title;       /* shipping: _titleCell @0x918 (stage2) */
    CGFloat _borderWidth;   /* shipping: aux storage (stage2) */
    CGFloat _cornerRadius;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _title = @"Title";
        /* conventional defaults; exact init bits are stage2 */
        self.borderType = NSBezelBorder;
        self.titlePosition = NSAtTop;
        self.boxType = NSBoxPrimary;
    }
    return self;
}

/* boxType: _bFlags bits 10-12 (0x18502c5c4 / setBoxType: 0x185093dd4 bfi #0xa,#3). */
- (NSBoxType)boxType { return (NSBoxType)((_bFlags >> 10) & 0x7u); }
- (void)setBoxType:(NSBoxType)boxType
{
    _bFlags = (_bFlags & ~(0x7u << 10)) | (((uint32_t)boxType & 0x7u) << 10);
}

/* borderType: _bFlags bits 0-1 (0x1850dd3ac / setBorderType: bfi #0,#2). */
- (NSBorderType)borderType { return (NSBorderType)(_bFlags & 0x3u); }
- (void)setBorderType:(NSBorderType)borderType
{
    _bFlags = (_bFlags & ~0x3u) | ((uint32_t)borderType & 0x3u);
}

/* titlePosition: _bFlags bits 2-4 (0x185093dbc / setTitlePosition: 0x1850ddb54 bfi #2,#3). */
- (NSTitlePosition)titlePosition { return (NSTitlePosition)((_bFlags >> 2) & 0x7u); }
- (void)setTitlePosition:(NSTitlePosition)titlePosition
{
    _bFlags = (_bFlags & ~(0x7u << 2)) | (((uint32_t)titlePosition & 0x7u) << 2);
}

/* isTransparent: _bFlags bit 9 (0x18502c734). */
- (BOOL)isTransparent { return (_bFlags >> 9) & 1u; }
- (void)setTransparent:(BOOL)transparent
{
    if (transparent) _bFlags |= (1u << 9);
    else             _bFlags &= ~(1u << 9);
}

/* title: _titleCell title in the binary (0x18562f62c); kept plainly here. */
- (NSString *)title { return _title ?: @""; }
- (void)setTitle:(NSString *)title { _title = [title copy]; }

- (CGFloat)borderWidth { return _borderWidth; }
- (void)setBorderWidth:(CGFloat)borderWidth { _borderWidth = borderWidth; }
- (CGFloat)cornerRadius { return _cornerRadius; }
- (void)setCornerRadius:(CGFloat)cornerRadius { _cornerRadius = cornerRadius; }

@end
