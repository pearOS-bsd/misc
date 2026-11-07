/*
 * NSButton.h — 1:1 reimplementation of AppKit's NSButton (core).
 *
 * NSButton is a pure delegator to its NSButtonCell (../evidence/button): every
 * accessor loads NSControl._cell and tail-calls the same selector on the cell.
 * state round-trips through the inherited NSCell _cFlags, so on/off/mixed works.
 */
#import "NSControl.h"
#import "NSButtonCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSButton : NSControl

+ (instancetype)buttonWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action;

@property (copy) NSString *title;
@property NSControlStateValue state;
@property NSBezelStyle bezelStyle;
- (void)setButtonType:(NSButtonType)type;

@end

NS_ASSUME_NONNULL_END
