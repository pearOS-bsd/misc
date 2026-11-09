/*
 * NSSwitch.h — 1:1 reimplementation (core). NSControl subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSSwitch : NSControl <NSAccessibilitySwitch> {
 *       q _presentationStateOverride;  {…} _currentTrackingState;
 *       @"<NSSwitchVisualProvider>" _visualProvider;  @"NSTouch" _trackingTouch;
 *   }
 *   -state -setState:   (plus the inherited NSControl target/action)
 *
 * A two-state toggle control. The core holds the on/off state and toggles it on
 * performClick:, then fires the control action. The visual provider (the drawn
 * knob/track) and the drag tracking are stage2.
 */
#import <Foundation/Foundation.h>
#import "NSControl.h"
#import "NSCell.h"   /* NSControlStateValue (On/Off/Mixed) */

NS_ASSUME_NONNULL_BEGIN

@interface NSSwitch : NSControl

@property NSControlStateValue state;
- (void)performClick:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
