/*
 * NSClipView.m — 1:1 (core). Evidence ../evidence/scroll: documentView
 * 0x184f6302c reads _docView ([self+0x3e8], retained+autoreleased). setDocumentView:
 * stores and, in the binary, adds it as a subview and observes its frame (stage2).
 */
#import "NSClipView.h"

@implementation NSClipView {
    NSView *_docView;   /* 0x3e8 */
}

- (NSView *)documentView { return _docView; }

- (void)setDocumentView:(NSView *)documentView
{
    if (_docView == documentView)
        return;
    [_docView removeFromSuperview];
    _docView = documentView;
    if (documentView)
        [self addSubview:documentView];
    /* TODO(stage2): frame-change observation + bounds sync for scrolling. */
}

@end
