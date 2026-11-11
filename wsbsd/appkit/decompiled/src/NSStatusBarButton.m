/*
 * NSStatusBarButton.m — behavioral-1:1 core. See NSStatusBarButton.h.
 */

#import "NSStatusBarButton.h"

@implementation NSStatusBarButton {
    BOOL _appearsDisabled;
    SEL _doubleAction;
    NSMenu *_statusMenu;
}

- (BOOL)appearsDisabled { return _appearsDisabled; }
- (void)setAppearsDisabled:(BOOL)v
{
    _appearsDisabled = v;
    /* TODO(stage2): looksDisabled drawing dims the button to ~0.4 alpha while it
     * stays enabled/clickable. */
}

- (SEL)doubleAction { return _doubleAction; }
- (void)setDoubleAction:(SEL)a { _doubleAction = a; }

- (NSMenu *)statusMenu { return _statusMenu; }
- (void)setStatusMenu:(NSMenu *)m { _statusMenu = m; }

@end
