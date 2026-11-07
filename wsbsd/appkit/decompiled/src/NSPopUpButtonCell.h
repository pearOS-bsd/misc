/*
 * NSPopUpButtonCell.h — 1:1 reimplementation (core).
 * Evidence ../evidence/popup: holds a _menu, a selected index (@0x400) and
 * _pbcFlags (@0x9e4, pullsDown = bit 0); numberOfItems delegates to the menu.
 * (Real hierarchy is NSPopUpButtonCell : NSMenuItemCell : NSButtonCell; we skip
 * NSMenuItemCell for now and subclass NSButtonCell — annotate, TODO(stage2).)
 */
#import "NSButtonCell.h"
#import "NSMenu.h"
#import "NSMenuItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSPopUpButtonCell : NSButtonCell
@property (strong) NSMenu *menu;
@property BOOL pullsDown;
@property (readonly) NSInteger numberOfItems;
@property (readonly) NSInteger indexOfSelectedItem;
@property (nullable, readonly) NSMenuItem *selectedItem;
- (void)addItemWithTitle:(NSString *)title;
- (void)selectItemAtIndex:(NSInteger)index;
- (nullable NSString *)titleOfSelectedItem;
@end

NS_ASSUME_NONNULL_END
