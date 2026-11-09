/*
 * NSAlert.m — 1:1 (core). Evidence ../evidence/alert:
 * messageText 0x1852808b0 ([self+0x40]), setMessageText: 0x185192008 (wraps in
 * NSAttributedString — stage2), alertStyle 0x185280eb4 ([self+0xd0]), buttons
 * 0x185280a58 ([self+0x28]), showsHelp 0x1851925f0 ([self+0xe1]).
 */
#import "NSAlert.h"

@implementation NSAlert {
    NSString *_messageText;       /* 0x40 */
    NSString *_informativeText;
    NSInteger _alertStyle;        /* 0xd0 */
    NSMutableArray<NSButton *> *_buttons;  /* 0x28 */
    BOOL _showsHelp;              /* 0xe1 */
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _messageText = @"";
        _informativeText = @"";
        _alertStyle = NSAlertStyleWarning;
        _buttons = [NSMutableArray array];
    }
    return self;
}

- (NSString *)messageText { return _messageText; }
- (void)setMessageText:(NSString *)messageText { _messageText = [messageText copy] ?: @""; }
- (NSString *)informativeText { return _informativeText; }
- (void)setInformativeText:(NSString *)informativeText { _informativeText = [informativeText copy] ?: @""; }

- (NSAlertStyle)alertStyle { return (NSAlertStyle)_alertStyle; }
- (void)setAlertStyle:(NSAlertStyle)alertStyle { _alertStyle = alertStyle; }

- (BOOL)showsHelp { return _showsHelp; }
- (void)setShowsHelp:(BOOL)showsHelp { _showsHelp = showsHelp; }

- (NSArray<NSButton *> *)buttons { return [_buttons copy]; }

/* addButtonWithTitle: build a button, append it, return it. The first button
 * added becomes the default (return-key) button, as in AppKit. */
- (NSButton *)addButtonWithTitle:(NSString *)title
{
    NSButton *button = [NSButton buttonWithTitle:title target:nil action:NULL];
    button.tag = 1000 + (NSInteger)_buttons.count;   /* NSAlertFirstButtonReturn + index */
    [_buttons addObject:button];
    return button;
}

@end
