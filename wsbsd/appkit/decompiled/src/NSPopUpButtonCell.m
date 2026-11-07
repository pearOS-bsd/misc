/*
 * NSPopUpButtonCell.m — 1:1 (core). Evidence ../evidence/popup:
 * menu @0x404 (menu 0x184f96e28), selected index @0x400 (indexOfSelectedItem),
 * pullsDown = _pbcFlags bit 0 (0x184f9e8dc), numberOfItems -> [menu numberOfItems]
 * (0x184f9ea88). selectItemAtIndex: 0x184f975c0.
 */
#import "NSPopUpButtonCell.h"

@implementation NSPopUpButtonCell {
    NSMenu *_menu;             /* 0x404 */
    NSInteger _selectedIndex;  /* 0x400 */
    uint32_t _pbcFlags;        /* 0x9e4 */
}

- (instancetype)init
{
    self = [super init];
    if (self) { _menu = [[NSMenu alloc] initWithTitle:@""]; _selectedIndex = -1; }
    return self;
}

- (NSMenu *)menu { return _menu; }
- (void)setMenu:(NSMenu *)menu { _menu = menu; if (_selectedIndex >= menu.numberOfItems) _selectedIndex = menu.numberOfItems - 1; }

- (BOOL)pullsDown { return (_pbcFlags & 0x1u) != 0; }         /* bit 0 */
- (void)setPullsDown:(BOOL)pullsDown { if (pullsDown) _pbcFlags |= 0x1u; else _pbcFlags &= ~0x1u; }

- (NSInteger)numberOfItems { return _menu.numberOfItems; }
- (NSInteger)indexOfSelectedItem { return _selectedIndex; }

- (NSMenuItem *)selectedItem
{
    if (_selectedIndex < 0 || _selectedIndex >= _menu.numberOfItems) return nil;
    return [_menu itemAtIndex:_selectedIndex];
}

- (void)addItemWithTitle:(NSString *)title
{
    [_menu addItemWithTitle:title action:NULL keyEquivalent:@""];
    if (_selectedIndex < 0) _selectedIndex = 0;   /* first item becomes selected */
}

- (void)selectItemAtIndex:(NSInteger)index
{
    if (index < -1 || index >= _menu.numberOfItems) return;
    _selectedIndex = index;
}

- (NSString *)titleOfSelectedItem { return [self selectedItem].title; }

@end
