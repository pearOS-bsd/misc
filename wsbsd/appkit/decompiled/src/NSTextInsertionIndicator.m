/*
 * NSTextInsertionIndicator.m — behavioral-1:1 core. See NSTextInsertionIndicator.h.
 */

#import "NSTextInsertionIndicator.h"

@implementation NSTextInsertionIndicator {
    NSColor *_color;
    NSTextInsertionIndicatorDisplayMode _displayMode;
    NSTextInsertionIndicatorAutomaticModeOptions _automaticModeOptions;
    id _effectsViewInserter;
}

- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _displayMode = NSTextInsertionIndicatorDisplayModeAutomatic;
        _automaticModeOptions = NSTextInsertionIndicatorAutomaticModeOptionsWhileTracking; /* measured: 1 */
        /* TODO(stage2): _color defaults to the semantic System textInsertionPointColor. */
    }
    return self;
}

- (NSColor *)color { return _color; }
- (void)setColor:(NSColor *)c { _color = c; /* NSColor is immutable; copy == retain */ }

- (NSTextInsertionIndicatorDisplayMode)displayMode { return _displayMode; }
- (void)setDisplayMode:(NSTextInsertionIndicatorDisplayMode)m { _displayMode = m; }

- (NSTextInsertionIndicatorAutomaticModeOptions)automaticModeOptions { return _automaticModeOptions; }
- (void)setAutomaticModeOptions:(NSTextInsertionIndicatorAutomaticModeOptions)o { _automaticModeOptions = o; }

- (id)effectsViewInserter { return _effectsViewInserter; }
- (void)setEffectsViewInserter:(id)b { _effectsViewInserter = [b copy]; }

/* TODO(stage2): wantsUpdateLayer/updateLayer blink+glow animation, the
 * current-state machine (updateCurrentState/updateSubstate), dictation/tracking
 * transitions and trailing-glow effects. */

@end
