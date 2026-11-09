/*
 * NSSwitch.m — 1:1 (core). See NSSwitch.h for the interface evidence.
 *
 * Holds the on/off state directly (the switch is not cell-backed for its state).
 * performClick: toggles On<->Off and sends the control's action via NSControl.
 * The drawn knob/track (NSSwitchVisualProvider) and the drag-to-toggle tracking
 * are stage2.
 */
#import "NSSwitch.h"

@implementation NSSwitch {
    NSControlStateValue _state;
}

- (NSControlStateValue)state { return _state; }
- (void)setState:(NSControlStateValue)state
{
    /* NSSwitch has only On/Off; any non-zero becomes On. */
    _state = (state != NSControlStateValueOff) ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)performClick:(id)sender
{
    self.state = (_state == NSControlStateValueOn) ? NSControlStateValueOff : NSControlStateValueOn;
    [self sendAction:self.action to:self.target];
}

@end
