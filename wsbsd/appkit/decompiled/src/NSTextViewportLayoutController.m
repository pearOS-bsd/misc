/*
 * NSTextViewportLayoutController.m — behavioral-1:1 core. See the header.
 */

#import "NSTextViewportLayoutController.h"

@implementation NSTextViewportLayoutController {
    __weak id<NSTextViewportLayoutControllerDelegate> _delegate;
    __weak NSTextLayoutManager *_textLayoutManager;
    CGRect _viewportBounds;
    NSTextRange *_viewportRange;
}

- (instancetype)initWithTextLayoutManager:(NSTextLayoutManager *)textLayoutManager
{
    self = [super init];
    if (self) {
        _textLayoutManager = textLayoutManager;
        /* delegate nil, viewportBounds zero, viewportRange nil (measured) */
    }
    return self;
}

- (id<NSTextViewportLayoutControllerDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSTextViewportLayoutControllerDelegate>)d { _delegate = d; }
- (NSTextLayoutManager *)textLayoutManager { return _textLayoutManager; }
- (CGRect)viewportBounds { return _viewportBounds; }
- (NSTextRange *)viewportRange { return _viewportRange; }

- (void)layoutViewport
{
    /* TODO(stage2): ask the delegate for the viewport bounds, lay the fragments
       that intersect it, and publish viewportBounds/viewportRange. */
}

- (void)adjustViewportByVerticalOffset:(double)verticalOffset { /* stage2 */ }
- (void)relocateViewportToTextLocation:(id<NSTextLocation>)textLocation { /* stage2 */ }

@end
