/*
 * NSColorPanel.m — behavioral-1:1 core. See the header.
 */

#import "NSColorPanel.h"

@implementation NSColorPanel {
    NSColor *_color;
    NSInteger _mode;
    BOOL _showsAlpha;
    BOOL _continuous;
    NSView *_accessoryView;
    __weak id _target;
    SEL _action;
}

static NSColorPanel *gShared;

+ (NSColorPanel *)sharedColorPanel
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gShared = [[self alloc] initWithContentRect:NSMakeRect(0, 0, 230, 360)
                                          styleMask:0 backing:2 defer:YES];
    });
    return gShared;
}

+ (BOOL)sharedColorPanelExists { return gShared != nil; }

- (instancetype)initWithContentRect:(NSRect)r styleMask:(NSUInteger)s backing:(NSUInteger)b defer:(BOOL)d
{
    self = [super initWithContentRect:r styleMask:s backing:b defer:d];
    if (self) {
        _mode = NSColorPanelModeWheel;   /* measured (6) */
        _showsAlpha = YES;               /* measured */
        _continuous = YES;               /* measured */
    }
    return self;
}

- (NSColor *)color { return _color; }
- (void)setColor:(NSColor *)c
{
    _color = c;
    /* a continuous panel fires its action on every change. */
    if (_continuous && _action && _target && [_target respondsToSelector:_action]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [_target performSelector:_action withObject:self];
#pragma clang diagnostic pop
    }
}
- (NSInteger)mode { return _mode; }
- (void)setMode:(NSInteger)m { _mode = m; }
- (BOOL)showsAlpha { return _showsAlpha; }
- (void)setShowsAlpha:(BOOL)v { _showsAlpha = v; }
- (BOOL)isContinuous { return _continuous; }
- (void)setContinuous:(BOOL)v { _continuous = v; }
- (NSView *)accessoryView { return _accessoryView; }
- (void)setAccessoryView:(NSView *)v { _accessoryView = v; }

- (void)setTarget:(id)target { _target = target; }
- (void)setAction:(SEL)action { _action = action; }
- (void)attachColorList:(NSColorList *)colorList {}   /* stage2 */
- (void)detachColorList:(NSColorList *)colorList {}   /* stage2 */

@end
