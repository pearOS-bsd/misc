/*
 * NSColorPickerTouchBarItem.m — behavioral-1:1 core. See the header.
 */

#import "NSColorPickerTouchBarItem.h"

typedef NS_ENUM(NSInteger, NSColorPickerTouchBarItemKind) {
    kFill = 0, kStroke = 1, kText = 2,
};

@implementation NSColorPickerTouchBarItem {
    NSColor *_color;
    BOOL _showsAlpha;
    NSColorList *_colorList;
    NSArray *_allowedColorSpaces;
    BOOL _colorListSupportsPressAndHoldVariants;
    NSString *_buttonTitle;
    NSImage *_buttonImage;
    __weak id _target;
    SEL _action;
    BOOL _enabled;
    NSString *_customizationLabel;
    NSColorPickerTouchBarItemKind _kind;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super initWithIdentifier:identifier];
    if (self) {
        _showsAlpha = YES;      /* measured */
        _enabled = YES;         /* measured */
        _allowedColorSpaces = @[];
        _customizationLabel = @"";
        /* TODO(stage2): _color defaults to the semantic black. */
    }
    return self;
}

+ (instancetype)colorPickerWithIdentifier:(NSString *)identifier { return [[self alloc] initWithIdentifier:identifier]; }
+ (instancetype)colorPickerWithIdentifier:(NSString *)identifier buttonImage:(NSImage *)image
{ NSColorPickerTouchBarItem *i = [[self alloc] initWithIdentifier:identifier]; i.buttonImage = image; return i; }
+ (instancetype)colorPickerWithIdentifier:(NSString *)identifier buttonTitle:(NSString *)title
{ NSColorPickerTouchBarItem *i = [[self alloc] initWithIdentifier:identifier]; i.buttonTitle = title; return i; }
+ (instancetype)strokeColorPickerWithIdentifier:(NSString *)identifier
{ NSColorPickerTouchBarItem *i = [[self alloc] initWithIdentifier:identifier]; i->_kind = kStroke; return i; }
+ (instancetype)textColorPickerWithIdentifier:(NSString *)identifier
{ NSColorPickerTouchBarItem *i = [[self alloc] initWithIdentifier:identifier]; i->_kind = kText; return i; }

- (NSColor *)color { return _color; }
- (void)setColor:(NSColor *)c { _color = c; }
- (BOOL)showsAlpha { return _showsAlpha; }
- (void)setShowsAlpha:(BOOL)v { _showsAlpha = v; }
- (NSColorList *)colorList { return _colorList; }
- (void)setColorList:(NSColorList *)l { _colorList = l; }
- (NSArray *)allowedColorSpaces { return _allowedColorSpaces; }
- (void)setAllowedColorSpaces:(NSArray *)a { _allowedColorSpaces = [a copy]; }
- (BOOL)colorListSupportsPressAndHoldVariants { return _colorListSupportsPressAndHoldVariants; }
- (void)setColorListSupportsPressAndHoldVariants:(BOOL)v { _colorListSupportsPressAndHoldVariants = v; }
- (NSString *)buttonTitle { return _buttonTitle; }
- (void)setButtonTitle:(NSString *)s { _buttonTitle = [s copy]; }
- (NSImage *)buttonImage { return _buttonImage; }
- (void)setButtonImage:(NSImage *)i { _buttonImage = i; }
- (id)target { return _target; }
- (void)setTarget:(id)t { _target = t; }
- (SEL)action { return _action; }
- (void)setAction:(SEL)a { _action = a; }
- (BOOL)isEnabled { return _enabled; }
- (void)setEnabled:(BOOL)e { _enabled = e; }
- (NSString *)customizationLabel { return _customizationLabel; }
- (void)setCustomizationLabel:(NSString *)s { _customizationLabel = [s copy] ?: @""; }

@end
