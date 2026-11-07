/*
 * NSTableColumn.m — 1:1 (core). Evidence ../evidence/tablecol:
 * identifier 0x184f6b7b4 ([self+0x10]), width 0x184f6e968 ([self+0x18]),
 * maxWidth 0x184f9d198 ([self+0x58]); setWidth: 0x184f9d1a0 clamps to
 * [minWidth, maxWidth]; isEditable 0x1857b4020 (flags 0x48 bit 1).
 */
#import "NSTableColumn.h"

@implementation NSTableColumn {
    NSString *_identifier;   /* 0x10 */
    CGFloat _width;          /* 0x18 */
    CGFloat _minWidth;
    CGFloat _maxWidth;       /* 0x58 */
    NSString *_title;        /* headerCell in the binary (stage2) */
    BOOL _editable;          /* flags 0x48 bit 1 */
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super init];
    if (self) {
        _identifier = [identifier copy] ?: @"";
        _width = 100.0;
        _minWidth = 10.0;
        _maxWidth = 1000.0;     /* conventional; exact init stage2 */
        _title = @"";
    }
    return self;
}

- (NSString *)identifier { return _identifier; }
- (void)setIdentifier:(NSString *)identifier { _identifier = [identifier copy]; }

- (CGFloat)width { return _width; }
/* setWidth: clamp to [minWidth, maxWidth] (0x184f9d1a0). */
- (void)setWidth:(CGFloat)width
{
    if (width < _minWidth) width = _minWidth;
    if (width > _maxWidth) width = _maxWidth;
    _width = width;
}

- (CGFloat)minWidth { return _minWidth; }
- (void)setMinWidth:(CGFloat)minWidth { _minWidth = minWidth; if (_width < minWidth) _width = minWidth; }
- (CGFloat)maxWidth { return _maxWidth; }
- (void)setMaxWidth:(CGFloat)maxWidth { _maxWidth = maxWidth; if (_width > maxWidth) _width = maxWidth; }

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)title { _title = [title copy]; }

- (BOOL)isEditable { return _editable; }
- (void)setEditable:(BOOL)editable { _editable = editable; }

@end
