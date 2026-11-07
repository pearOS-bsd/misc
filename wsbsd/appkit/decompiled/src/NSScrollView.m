/*
 * NSScrollView.m — 1:1 (core). Evidence ../evidence/scroll:
 * contentView 0x184f634dc ([self+0x890]); documentView 0x184f63004 ->
 * [[self contentView] documentView]; borderType 0x185137a54 (_sFlags bits 25-26).
 */
#import "NSScrollView.h"

enum : uint32_t { NSScrollViewBorderShift = 25, NSScrollViewBorderMask = 0x3u << 25 };

@implementation NSScrollView {
    NSClipView *_contentView;   /* 0x890 */
    uint32_t _sFlags;           /* 0x898 (borderType bits 25-26) */
    BOOL _hasVerticalScroller;  /* shipping: packed in _sFlags (stage2) */
    BOOL _hasHorizontalScroller;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _contentView = [[NSClipView alloc] initWithFrame:CGRectMake(0, 0,
                                        frameRect.size.width, frameRect.size.height)];
        [self addSubview:_contentView];
    }
    return self;
}

- (NSClipView *)contentView { return _contentView; }
- (void)setContentView:(NSClipView *)contentView
{
    if (contentView == _contentView) return;
    [_contentView removeFromSuperview];
    _contentView = contentView;
    if (contentView) [self addSubview:contentView];
}

/* documentView delegates to the clip view. */
- (NSView *)documentView { return _contentView.documentView; }
- (void)setDocumentView:(NSView *)documentView { _contentView.documentView = documentView; }

- (BOOL)hasVerticalScroller { return _hasVerticalScroller; }
- (void)setHasVerticalScroller:(BOOL)v { _hasVerticalScroller = v; }
- (BOOL)hasHorizontalScroller { return _hasHorizontalScroller; }
- (void)setHasHorizontalScroller:(BOOL)v { _hasHorizontalScroller = v; }

/* borderType = _sFlags bits 25-26 (0x185137a54). */
- (NSBorderType)borderType { return (NSBorderType)((_sFlags & NSScrollViewBorderMask) >> NSScrollViewBorderShift); }
- (void)setBorderType:(NSBorderType)borderType
{
    _sFlags = (_sFlags & ~NSScrollViewBorderMask) | (((uint32_t)borderType << NSScrollViewBorderShift) & NSScrollViewBorderMask);
}

@end
