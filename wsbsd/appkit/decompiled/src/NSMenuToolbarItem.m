/*
 * NSMenuToolbarItem.m — 1:1 (core). See NSMenuToolbarItem.h for the evidence.
 *
 * Tracks the dropped menu, the showsIndicator flag (default YES, matching the
 * pull-down chevron) and target/action. The pull-down control view and the
 * disclosure indicator drawing are stage2.
 */
#import "NSMenuToolbarItem.h"

@implementation NSMenuToolbarItem {
    NSMenu *_menu;
    BOOL _showsIndicator;
    __weak id _target;
    SEL _action;
}

- (instancetype)initWithItemIdentifier:(NSString *)itemIdentifier
{
    self = [super initWithItemIdentifier:itemIdentifier];
    if (self) { _showsIndicator = YES; }
    return self;
}

- (NSMenu *)menu { return _menu; }
- (void)setMenu:(NSMenu *)menu { _menu = menu; }
- (BOOL)showsIndicator { return _showsIndicator; }
- (void)setShowsIndicator:(BOOL)v { _showsIndicator = v; }
- (id)target { return _target; }
- (void)setTarget:(id)t { _target = t; }
- (SEL)action { return _action; }
- (void)setAction:(SEL)a { _action = a; }

@end
