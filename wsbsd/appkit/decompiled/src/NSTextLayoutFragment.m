/*
 * NSTextLayoutFragment.m — behavioral-1:1 core. See the header.
 */

#import "NSTextLayoutFragment.h"

@implementation NSTextLayoutFragment {
    __weak NSTextLayoutManager *_textLayoutManager;
    __weak NSTextElement *_textElement;
    NSTextRange *_rangeInElement;
    NSArray *_textLineFragments;
    NSTextLayoutFragmentState _state;
    CGRect _layoutFragmentFrame;
}

- (instancetype)initWithTextElement:(NSTextElement *)textElement range:(NSTextRange *)rangeInElement
{
    self = [super init];
    if (self) {
        _textElement = textElement;
        _rangeInElement = rangeInElement;
        _state = NSTextLayoutFragmentStateNone;   /* measured */
        /* textLineFragments nil, frame zero, textLayoutManager nil (measured) */
    }
    return self;
}

- (NSTextLayoutManager *)textLayoutManager { return _textLayoutManager; }
- (void)setTextLayoutManager:(NSTextLayoutManager *)m { _textLayoutManager = m; }
- (NSTextElement *)textElement { return _textElement; }
- (NSTextRange *)rangeInElement { return _rangeInElement; }
- (NSArray *)textLineFragments { return _textLineFragments; }
- (void)setTextLineFragments:(NSArray *)f { _textLineFragments = [f copy]; }
- (NSTextLayoutFragmentState)state { return _state; }
- (void)setState:(NSTextLayoutFragmentState)s { _state = s; }
- (CGRect)layoutFragmentFrame { return _layoutFragmentFrame; }
- (void)setLayoutFragmentFrame:(CGRect)r { _layoutFragmentFrame = r; }

- (CGRect)renderingSurfaceBounds { return CGRectZero; }  /* derived from line fragments = stage2 */

- (void)invalidateLayout
{
    _state = NSTextLayoutFragmentStateNone;
    _textLineFragments = nil;
    _layoutFragmentFrame = CGRectZero;
}

@end
