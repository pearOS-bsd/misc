/*
 * NSText.m — behavioral-1:1 core. See the header.
 */

#import "NSText.h"

@implementation NSText {
    NSMutableString *_string;
    NSRange _selectedRange;
    BOOL _editable, _selectable, _richText, _fieldEditor, _usesFontPanel, _drawsBackground;
    BOOL _horizontallyResizable, _verticallyResizable;
    NSTextAlignment _alignment;
    NSColor *_backgroundColor, *_textColor;
    NSFont *_font;
    __weak id _delegate;
}

- (instancetype)initWithFrame:(CGRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _string = [NSMutableString string];
        _selectedRange = NSMakeRange(0, 0);
        _editable = YES;              /* measured */
        _selectable = YES;            /* measured */
        _richText = YES;              /* measured */
        _usesFontPanel = YES;         /* measured */
        _drawsBackground = YES;       /* measured */
        _verticallyResizable = YES;   /* measured */
        _alignment = NSTextAlignmentNatural;  /* measured (4) */
        /* fieldEditor=NO, horizontallyResizable=NO (measured) */
    }
    return self;
}

- (NSString *)string { return [_string copy]; }
- (void)setString:(NSString *)s
{
    _string = [(s ?: @"") mutableCopy];
    [self _clampSelection];
}

- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)aString
{
    if (NSMaxRange(range) > _string.length) return;
    [_string replaceCharactersInRange:range withString:(aString ?: @"")];
    [self _clampSelection];
}

- (void)_clampSelection
{
    NSUInteger len = _string.length;
    NSUInteger loc = MIN(_selectedRange.location, len);
    NSUInteger maxLen = len - loc;
    _selectedRange = NSMakeRange(loc, MIN(_selectedRange.length, maxLen));
}

- (NSRange)selectedRange { return _selectedRange; }
- (void)setSelectedRange:(NSRange)r
{
    NSUInteger len = _string.length;
    NSUInteger loc = MIN(r.location, len);
    _selectedRange = NSMakeRange(loc, MIN(r.length, len - loc));
}

- (void)scrollRangeToVisible:(NSRange)range { /* TODO(stage2): scroll layout to the range */ }

- (BOOL)isEditable { return _editable; }
- (void)setEditable:(BOOL)v { _editable = v; if (v) _selectable = YES; }
- (BOOL)isSelectable { return _selectable; }
- (void)setSelectable:(BOOL)v { _selectable = v; if (!v) _editable = NO; }
- (BOOL)isRichText { return _richText; }
- (void)setRichText:(BOOL)v { _richText = v; }
- (BOOL)isFieldEditor { return _fieldEditor; }
- (void)setFieldEditor:(BOOL)v { _fieldEditor = v; }
- (BOOL)usesFontPanel { return _usesFontPanel; }
- (void)setUsesFontPanel:(BOOL)v { _usesFontPanel = v; }
- (BOOL)drawsBackground { return _drawsBackground; }
- (void)setDrawsBackground:(BOOL)v { _drawsBackground = v; }
- (BOOL)isHorizontallyResizable { return _horizontallyResizable; }
- (void)setHorizontallyResizable:(BOOL)v { _horizontallyResizable = v; }
- (BOOL)isVerticallyResizable { return _verticallyResizable; }
- (void)setVerticallyResizable:(BOOL)v { _verticallyResizable = v; }
- (NSTextAlignment)alignment { return _alignment; }
- (void)setAlignment:(NSTextAlignment)a { _alignment = a; }
- (NSColor *)backgroundColor { return _backgroundColor; }
- (void)setBackgroundColor:(NSColor *)c { _backgroundColor = c; }
- (NSColor *)textColor { return _textColor; }
- (void)setTextColor:(NSColor *)c { _textColor = c; }
- (NSFont *)font { return _font; }
- (void)setFont:(NSFont *)f { _font = f; }
- (id)delegate { return _delegate; }
- (void)setDelegate:(id)d { _delegate = d; }

@end
