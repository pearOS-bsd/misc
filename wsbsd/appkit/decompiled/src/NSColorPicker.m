/*
 * NSColorPicker.m — behavioral-1:1 core. See the header.
 */

#import "NSColorPicker.h"

@implementation NSColorPicker {
    NSColorPanel *_colorPanel;
    NSUInteger _mask;
    NSColorPanelMode _mode;
    NSString *_buttonToolTip;
}

- (instancetype)initWithPickerMask:(NSUInteger)mask colorPanel:(NSColorPanel *)owningColorPanel
{
    self = [super init];
    if (self) {
        _mask = mask;
        _colorPanel = owningColorPanel;
    }
    return self;
}

- (NSColorPanel *)colorPanel { return _colorPanel; }
- (NSUInteger)pickerMask { return _mask; }
- (NSColorPanelMode)currentMode { return _mode; }

- (NSString *)buttonToolTip
{
    /* base default is the class name (measured "NSColorPicker"). */
    return _buttonToolTip ?: NSStringFromClass([self class]);
}

- (NSImage *)provideNewButtonImage
{
    /* abstract: a real picker returns its toolbar button image. */
    return nil;  /* TODO(stage2): subclass responsibility */
}

- (CGSize)minContentSize
{
    /* abstract: derived from the subclass's -provideNewView:. */
    return CGSizeZero;  /* TODO(stage2): subclass responsibility (raw base throws) */
}

- (void)setMode:(NSColorPanelMode)mode { _mode = mode; }   /* base stores; subclass switches UI */
- (void)attachColorList:(NSColorList *)colorList {}         /* no-op in base */
- (void)detachColorList:(NSColorList *)colorList {}         /* no-op in base */
- (void)alphaControlAddedOrRemoved:(id)sender {}            /* no-op in base */
- (void)viewSizeChanged:(id)sender {}                       /* no-op in base */

@end
