/*
 * NSButton.m — 1:1 reimplementation of AppKit's NSButton (core).
 * Addresses cite the macOS 27 arm64e disassembly under ../evidence/button.
 * Each accessor loads NSControl._cell and tail-calls the cell's same selector.
 */
#import "NSButton.h"

@implementation NSButton

+ (Class)cellClass { return [NSButtonCell class]; }

- (NSButtonCell *)buttonCell { return (NSButtonCell *)self.cell; }

/* -[NSButton title] 0x184fbede4 / setTitle: 0x184f50590 -> cell */
- (NSString *)title { return [self.buttonCell title]; }
- (void)setTitle:(NSString *)title { [self.buttonCell setTitle:title]; }

/* -[NSButton state] 0x184febc1c -> [cell state] */
- (NSControlStateValue)state { return [self.buttonCell state]; }

/* -[NSButton setState:] 0x184f51278: compare with [cell state], set if changed.
 * (The binary then redisplays — TODO(stage2).) */
- (void)setState:(NSControlStateValue)state
{
    NSButtonCell *cell = self.buttonCell;
    if ([cell state] != state)
        [cell setState:state];
}

/* -[NSButton bezelStyle] 0x18502afb8 / setBezelStyle: 0x184f4949c -> cell */
- (NSBezelStyle)bezelStyle { return [self.buttonCell bezelStyle]; }
- (void)setBezelStyle:(NSBezelStyle)bezelStyle { [self.buttonCell setBezelStyle:bezelStyle]; }

/* -[NSButton setButtonType:] 0x184f4c264 -> cell */
- (void)setButtonType:(NSButtonType)type { [self.buttonCell setButtonType:type]; }

/* +[NSButton buttonWithTitle:target:action:] 0x1850634b0
 * Build a momentary push-in button, set title/target/action. (sizeToFit of the
 * real convenience constructor is stage2.) */
+ (instancetype)buttonWithTitle:(NSString *)title target:(id)target action:(SEL)action
{
    NSButton *button = [[self alloc] initWithFrame:CGRectZero];
    button.title = title;
    button.target = target;
    button.action = action;
    [button setButtonType:NSButtonTypeMomentaryPushIn];
    button.bezelStyle = NSBezelStylePush;
    return button;
}

@end
