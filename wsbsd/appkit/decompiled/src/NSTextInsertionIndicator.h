/*
 * NSTextInsertionIndicator.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSTextInsertionIndicator (: NSView), the modern blinking/glowing text caret
 * view (macOS 15+).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSTextInsertionIndicator_interface.txt. Real ivars: _color,
 * _displayMode, _currentState, _substate, the CALayer/CAShapeLayer/TUIGlowEffect
 * rendering stack, and the blink/dictation/tracking state flags.
 *
 * Measured on this Mac: automaticModeOptions defaults to WhileTracking(1); the
 * default color is the semantic System textInsertionPointColor. The -displayMode
 * getter reflects an internal current-state machine (it returned 100 standalone,
 * not the set value) gated by the window/CALayer presentation — that state
 * machine, the blink/glow animation and the semantic color are TODO(stage2).
 * This core reproduces the documented displayMode/automaticModeOptions/color/
 * effectsViewInserter value contract.
 */

#import "NSView.h"

NS_ASSUME_NONNULL_BEGIN

@class NSColor;

typedef NS_ENUM(NSInteger, NSTextInsertionIndicatorDisplayMode) {
    NSTextInsertionIndicatorDisplayModeAutomatic = 0,
    NSTextInsertionIndicatorDisplayModeHidden    = 1,
    NSTextInsertionIndicatorDisplayModeVisible   = 2,
};

typedef NS_OPTIONS(NSInteger, NSTextInsertionIndicatorAutomaticModeOptions) {
    NSTextInsertionIndicatorAutomaticModeOptionsWhileTracking   = 1 << 0,
    NSTextInsertionIndicatorAutomaticModeOptionsShowEffectsView = 1 << 1,
};

@interface NSTextInsertionIndicator : NSView

@property (copy) NSColor *color;
@property NSTextInsertionIndicatorDisplayMode displayMode;                    /* default Automatic */
@property NSTextInsertionIndicatorAutomaticModeOptions automaticModeOptions;  /* default WhileTracking */
@property (nullable, copy) id effectsViewInserter;

@end

NS_ASSUME_NONNULL_END
