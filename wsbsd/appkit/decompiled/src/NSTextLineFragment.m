/*
 * NSTextLineFragment.m — behavioral-1:1 core. See the header.
 */

#import "NSTextLineFragment.h"

@implementation NSTextLineFragment {
    NSAttributedString *_attributedString;
    NSRange _characterRange;
    CGRect _typographicBounds;
    CGPoint _glyphOrigin;
    double _padding;
    BOOL _extra;
    __weak NSTextLayoutFragment *_textLayoutFragment;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString range:(NSRange)range
{
    self = [super init];
    if (self) {
        _attributedString = attributedString;
        _characterRange = range;
        /* geometry is zero until laid out (measured). */
    }
    return self;
}

- (instancetype)initWithString:(NSString *)string attributes:(NSDictionary *)attributes range:(NSRange)range
{
    NSAttributedString *as = string ? [[NSAttributedString alloc] initWithString:string attributes:attributes] : nil;
    return [self initWithAttributedString:as range:range];
}

- (NSAttributedString *)attributedString { return _attributedString; }
- (NSRange)characterRange { return _characterRange; }
- (CGRect)typographicBounds { return _typographicBounds; }
- (CGPoint)glyphOrigin { return _glyphOrigin; }
- (double)padding { return _padding; }
- (void)setPadding:(double)p { _padding = p; }
- (BOOL)isExtra { return _extra; }
- (void)setExtra:(BOOL)e { _extra = e; }
- (NSTextLayoutFragment *)textLayoutFragment { return _textLayoutFragment; }
- (void)setTextLayoutFragment:(NSTextLayoutFragment *)f { _textLayoutFragment = f; }

- (void)setGlyphOrigin:(CGPoint)glyphOrigin { _glyphOrigin = glyphOrigin; }
- (void)setTypographicBounds:(CGRect)typographicBounds { _typographicBounds = typographicBounds; }

- (CGPoint)locationForCharacterAtIndex:(NSInteger)index
{
    /* TODO(stage2): CTLineGetOffsetForStringIndex of the laid-out line.
       Standalone (un-laid-out) the real class returns the origin. */
    return CGPointZero;
}

- (NSInteger)characterIndexForPoint:(CGPoint)point
{
    /* TODO(stage2): CTLineGetStringIndexForPosition. Standalone the real class
       returns the range start (0 for a fragment at string offset 0). */
    return (NSInteger)_characterRange.location;
}

@end
