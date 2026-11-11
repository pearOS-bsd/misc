/*
 * NSFormCell.m — behavioral-1:1 core. See NSFormCell.h.
 */

#import "NSFormCell.h"

@implementation NSFormCell {
    NSString *_title;
    NSFont *_titleFont;
    CGFloat _titleWidth;
    NSTextAlignment _titleAlignment;
    NSWritingDirection _titleBaseWritingDirection;
    NSString *_placeholderString;
    NSAttributedString *_placeholderAttributedString;
    CGFloat _preferredTextFieldWidth;
    NSAttributedString *_attributedTitle;
}

- (instancetype)initTextCell:(NSString *)string
{
    self = [super init];
    if (self) {
        _title = [string copy] ?: @"";
        _titleWidth = -1.0;                                  /* auto */
        _titleAlignment = NSTextAlignmentRight;              /* measured */
        _titleBaseWritingDirection = NSWritingDirectionNatural;
        _preferredTextFieldWidth = -1.0;                     /* measured */
    }
    return self;
}

- (instancetype)init { return [self initTextCell:@""]; }
- (instancetype)initWithCoder:(NSCoder *)coder { return [self initTextCell:@""]; }

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)t { _title = [t copy] ?: @""; }

- (NSFont *)titleFont { return _titleFont; }
- (void)setTitleFont:(NSFont *)f { _titleFont = f; }

- (CGFloat)titleWidth { return _titleWidth; }   /* stage2: when -1, auto = title text width */
- (void)setTitleWidth:(CGFloat)w { _titleWidth = w; }

- (NSTextAlignment)titleAlignment { return _titleAlignment; }
- (void)setTitleAlignment:(NSTextAlignment)a { _titleAlignment = a; }

- (NSWritingDirection)titleBaseWritingDirection { return _titleBaseWritingDirection; }
- (void)setTitleBaseWritingDirection:(NSWritingDirection)d { _titleBaseWritingDirection = d; }

- (NSString *)placeholderString { return _placeholderString; }
- (void)setPlaceholderString:(NSString *)s { _placeholderString = [s copy]; _placeholderAttributedString = nil; }
- (NSAttributedString *)placeholderAttributedString { return _placeholderAttributedString; }
- (void)setPlaceholderAttributedString:(NSAttributedString *)s { _placeholderAttributedString = [s copy]; _placeholderString = nil; }

- (CGFloat)preferredTextFieldWidth { return _preferredTextFieldWidth; }
- (void)setPreferredTextFieldWidth:(CGFloat)w { _preferredTextFieldWidth = w; }

- (NSAttributedString *)attributedTitle { return _attributedTitle; }
- (void)setAttributedTitle:(NSAttributedString *)s { _attributedTitle = [s copy]; if (s) _title = [[s string] copy]; }

- (id)copyWithZone:(NSZone *)zone
{
    NSFormCell *c = [[[self class] alloc] initTextCell:_title];
    c->_titleFont = _titleFont;
    c->_titleWidth = _titleWidth;
    c->_titleAlignment = _titleAlignment;
    c->_titleBaseWritingDirection = _titleBaseWritingDirection;
    c->_placeholderString = [_placeholderString copy];
    c->_placeholderAttributedString = [_placeholderAttributedString copy];
    c->_preferredTextFieldWidth = _preferredTextFieldWidth;
    c->_attributedTitle = [_attributedTitle copy];
    return c;
}

/* TODO(stage2): drawingRectForBounds:/cellSizeForBounds:/drawWithFrame: and the
 * auto titleWidth computed from the title cell's font metrics. */

@end
