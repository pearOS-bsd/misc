/*
 * NSButtonTouchBarItem.m — behavioral-1:1 core. See NSButtonTouchBarItem.h.
 */

#import "NSButtonTouchBarItem.h"

@implementation NSButtonTouchBarItem {
    NSString *_title;
    NSImage *_image;
    NSColor *_bezelColor;
    __weak id _target;
    SEL _action;
    BOOL _enabled;
    NSString *_customizationLabel;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super initWithIdentifier:identifier];
    if (self) {
        _title = @"";       /* measured */
        _enabled = YES;     /* measured */
        _customizationLabel = @"";
    }
    return self;
}

+ (instancetype)buttonTouchBarItemWithIdentifier:(NSString *)identifier title:(NSString *)title image:(NSImage *)image target:(id)target action:(SEL)action
{
    NSButtonTouchBarItem *item = [[self alloc] initWithIdentifier:identifier];
    if (title) item.title = title;
    item.image = image;
    item.target = target;
    item.action = action;
    return item;
}

+ (instancetype)buttonTouchBarItemWithIdentifier:(NSString *)identifier title:(NSString *)title target:(id)target action:(SEL)action
{ return [self buttonTouchBarItemWithIdentifier:identifier title:title image:nil target:target action:action]; }

+ (instancetype)buttonTouchBarItemWithIdentifier:(NSString *)identifier image:(NSImage *)image target:(id)target action:(SEL)action
{ return [self buttonTouchBarItemWithIdentifier:identifier title:@"" image:image target:target action:action]; }

- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)t { _title = [t copy] ?: @""; }
- (NSImage *)image { return _image; }
- (void)setImage:(NSImage *)i { _image = i; }
- (NSColor *)bezelColor { return _bezelColor; }
- (void)setBezelColor:(NSColor *)c { _bezelColor = c; }
- (id)target { return _target; }
- (void)setTarget:(id)t { _target = t; }
- (SEL)action { return _action; }
- (void)setAction:(SEL)a { _action = a; }
- (BOOL)isEnabled { return _enabled; }
- (void)setEnabled:(BOOL)e { _enabled = e; }
- (NSString *)customizationLabel { return _customizationLabel; }
- (void)setCustomizationLabel:(NSString *)s { _customizationLabel = [s copy] ?: @""; }

/* -view lazily builds an NSButton bound to title/image/target/action — stage2. */

@end
