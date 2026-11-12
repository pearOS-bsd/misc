/*
 * NSPickerTouchBarItem.m — behavioral-1:1 core. See NSPickerTouchBarItem.h.
 */

#import "NSPickerTouchBarItem.h"

@implementation NSPickerTouchBarItem {
    NSMutableArray *_labels;   /* NSString or NSNull */
    NSMutableArray *_images;   /* NSImage or NSNull */
    NSMutableArray *_enabled;  /* NSNumber(BOOL) */
    NSInteger _selectedIndex;
    NSPickerTouchBarItemSelectionMode _selectionMode;
    NSPickerTouchBarItemControlRepresentation _controlRepresentation;
    NSString *_collapsedRepresentationLabel;
    NSImage *_collapsedRepresentationImage;
    NSColor *_selectionColor;
    __weak id _target;
    SEL _action;
    BOOL _itemEnabled;
    NSString *_customizationLabel;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    self = [super initWithIdentifier:identifier];
    if (self) {
        _labels = [NSMutableArray array];
        _images = [NSMutableArray array];
        _enabled = [NSMutableArray array];
        _selectedIndex = -1;          /* measured */
        _itemEnabled = YES;           /* measured */
        _customizationLabel = @"";
    }
    return self;
}

+ (instancetype)pickerTouchBarItemWithIdentifier:(NSString *)identifier labels:(NSArray<NSString *> *)labels selectionMode:(NSPickerTouchBarItemSelectionMode)mode target:(id)target action:(SEL)action
{
    NSPickerTouchBarItem *p = [[self alloc] initWithIdentifier:identifier];
    p.selectionMode = mode; p.target = target; p.action = action;
    [p setNumberOfOptions:(NSInteger)labels.count];
    for (NSInteger i = 0; i < (NSInteger)labels.count; i++) [p setLabel:labels[i] atIndex:i];
    return p;
}

+ (instancetype)pickerTouchBarItemWithIdentifier:(NSString *)identifier images:(NSArray<NSImage *> *)images selectionMode:(NSPickerTouchBarItemSelectionMode)mode target:(id)target action:(SEL)action
{
    NSPickerTouchBarItem *p = [[self alloc] initWithIdentifier:identifier];
    p.selectionMode = mode; p.target = target; p.action = action;
    [p setNumberOfOptions:(NSInteger)images.count];
    for (NSInteger i = 0; i < (NSInteger)images.count; i++) [p setImage:images[i] atIndex:i];
    return p;
}

- (NSInteger)numberOfOptions { return (NSInteger)_labels.count; }
- (void)setNumberOfOptions:(NSInteger)n
{
    if (n < 0) n = 0;
    while ((NSInteger)_labels.count < n) { [_labels addObject:[NSNull null]]; [_images addObject:[NSNull null]]; [_enabled addObject:@YES]; }
    while ((NSInteger)_labels.count > n) { [_labels removeLastObject]; [_images removeLastObject]; [_enabled removeLastObject]; }
    if (_selectedIndex >= n) _selectedIndex = -1;
}

- (NSInteger)selectedIndex { return _selectedIndex; }
- (void)setSelectedIndex:(NSInteger)i { _selectedIndex = (i >= -1 && i < (NSInteger)_labels.count) ? i : -1; }
- (NSPickerTouchBarItemSelectionMode)selectionMode { return _selectionMode; }
- (void)setSelectionMode:(NSPickerTouchBarItemSelectionMode)m { _selectionMode = m; }
- (NSPickerTouchBarItemControlRepresentation)controlRepresentation { return _controlRepresentation; }
- (void)setControlRepresentation:(NSPickerTouchBarItemControlRepresentation)r { _controlRepresentation = r; }
- (NSString *)collapsedRepresentationLabel { return _collapsedRepresentationLabel; }
- (void)setCollapsedRepresentationLabel:(NSString *)s { _collapsedRepresentationLabel = [s copy]; }
- (NSImage *)collapsedRepresentationImage { return _collapsedRepresentationImage; }
- (void)setCollapsedRepresentationImage:(NSImage *)i { _collapsedRepresentationImage = i; }
- (NSColor *)selectionColor { return _selectionColor; }
- (void)setSelectionColor:(NSColor *)c { _selectionColor = c; }
- (id)target { return _target; }
- (void)setTarget:(id)t { _target = t; }
- (SEL)action { return _action; }
- (void)setAction:(SEL)a { _action = a; }
- (BOOL)isEnabled { return _itemEnabled; }
- (void)setEnabled:(BOOL)e { _itemEnabled = e; }
- (NSString *)customizationLabel { return _customizationLabel; }
- (void)setCustomizationLabel:(NSString *)s { _customizationLabel = [s copy] ?: @""; }

- (NSString *)labelAtIndex:(NSInteger)i
{
    if (i < 0 || i >= (NSInteger)_labels.count) return nil;
    id v = _labels[i]; return (v == [NSNull null]) ? nil : v;
}
- (void)setLabel:(NSString *)label atIndex:(NSInteger)i
{
    if (i >= 0 && i < (NSInteger)_labels.count) _labels[i] = label ? [label copy] : [NSNull null];
}
- (NSImage *)imageAtIndex:(NSInteger)i
{
    if (i < 0 || i >= (NSInteger)_images.count) return nil;
    id v = _images[i]; return (v == [NSNull null]) ? nil : v;
}
- (void)setImage:(NSImage *)image atIndex:(NSInteger)i
{
    if (i >= 0 && i < (NSInteger)_images.count) _images[i] = image ? (id)image : (id)[NSNull null];
}
- (BOOL)isEnabledAtIndex:(NSInteger)i
{
    if (i < 0 || i >= (NSInteger)_enabled.count) return NO;
    return [_enabled[i] boolValue];
}
- (void)setEnabled:(BOOL)enabled atIndex:(NSInteger)i
{
    if (i >= 0 && i < (NSInteger)_enabled.count) _enabled[i] = @(enabled);
}

@end
