/*
 * NSFontPanel.m — behavioral-1:1 core. See the header.
 */

#import "NSFontPanel.h"

@implementation NSFontPanel {
    NSView *_accessoryView;
    BOOL _worksWhenModal;
    BOOL _enabled;
    NSFont *_panelFont;
    BOOL _isMultiple;
}

static NSFontPanel *gShared;

+ (NSFontPanel *)sharedFontPanel
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gShared = [[self alloc] initWithContentRect:NSMakeRect(0, 0, 350, 300)
                                          styleMask:0 backing:2 defer:YES];
    });
    return gShared;
}

+ (BOOL)sharedFontPanelExists { return gShared != nil; }

- (instancetype)initWithContentRect:(NSRect)r styleMask:(NSUInteger)s backing:(NSUInteger)b defer:(BOOL)d
{
    self = [super initWithContentRect:r styleMask:s backing:b defer:d];
    if (self) {
        _worksWhenModal = YES;   /* measured */
        _enabled = YES;          /* measured */
    }
    return self;
}

- (NSView *)accessoryView { return _accessoryView; }
- (void)setAccessoryView:(NSView *)v { _accessoryView = v; }
- (BOOL)worksWhenModal { return _worksWhenModal; }
- (void)setWorksWhenModal:(BOOL)v { _worksWhenModal = v; }
- (BOOL)isEnabled { return _enabled; }
- (void)setEnabled:(BOOL)v { _enabled = v; }

- (void)setPanelFont:(NSFont *)fontObj isMultiple:(BOOL)flag
{
    _panelFont = fontObj;
    _isMultiple = flag;
}

- (NSFont *)panelConvertFont:(NSFont *)fontObj
{
    /* The real panel maps the user's selection onto fontObj via NSFontManager.
       Standalone there is no selection, so it returns the input unchanged. */
    return fontObj;   /* TODO(stage2): apply the panel's current trait selection */
}

@end
