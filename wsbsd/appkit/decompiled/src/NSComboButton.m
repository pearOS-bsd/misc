/*
 * NSComboButton.m — behavioral-1:1 core. See NSComboButton.h.
 */

#import "NSComboButton.h"

@implementation NSComboButton {
    NSString *_title;
    NSImage *_image;
    NSImageScaling _imageScaling;
    NSMenu *_menu;
    NSComboButtonStyle _style;
    __weak id _comboTarget;
    SEL _comboAction;
}

/* NSComboButton stores its own target/action (it overrides -setAction:), rather
 * than routing through a cell like a classic NSControl. */
- (id)target { return _comboTarget; }
- (void)setTarget:(id)target { _comboTarget = target; }
- (SEL)action { return _comboAction; }
- (void)setAction:(SEL)action { _comboAction = action; }

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _title = @"";                 /* measured: empty, not nil */
        _style = NSComboButtonStyleSplit;
        _imageScaling = NSImageScaleProportionallyDown;
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) { if (!_title) _title = @""; }
    return self;
}

+ (instancetype)comboButtonWithTitle:(NSString *)title image:(NSImage *)image menu:(NSMenu *)menu target:(id)target action:(SEL)action
{
    NSComboButton *b = [[self alloc] initWithFrame:NSZeroRect];
    b.title = title;
    b.image = image;
    b.menu = menu;
    b.target = target;
    b.action = action;
    return b;
}

+ (instancetype)comboButtonWithTitle:(NSString *)title menu:(NSMenu *)menu target:(id)target action:(SEL)action
{
    return [self comboButtonWithTitle:title image:nil menu:menu target:target action:action];
}

+ (instancetype)comboButtonWithImage:(NSImage *)image menu:(NSMenu *)menu target:(id)target action:(SEL)action
{
    return [self comboButtonWithTitle:@"" image:image menu:menu target:target action:action];
}

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)t { _title = t ? [t copy] : @""; }   /* null_resettable */
- (NSImage *)image { return _image; }
- (void)setImage:(NSImage *)i { _image = i; }
- (NSImageScaling)imageScaling { return _imageScaling; }
- (void)setImageScaling:(NSImageScaling)s { _imageScaling = s; }
- (NSMenu *)menu { return _menu; }
- (void)setMenu:(NSMenu *)m { _menu = m; }
- (NSComboButtonStyle)style { return _style; }
- (void)setStyle:(NSComboButtonStyle)s { _style = s; }

/* TODO(stage2): build the backing NSSegmentedControl, intrinsicContentSize/
 * alignmentRectInsets, and present `menu` from the disclosure segment. */

@end
