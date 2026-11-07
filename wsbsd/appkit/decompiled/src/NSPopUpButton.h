/* NSPopUpButton.h — 1:1 (core). NSButton backed by NSPopUpButtonCell; delegates. */
#import "NSButton.h"
#import "NSPopUpButtonCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSPopUpButton : NSButton
@property BOOL pullsDown;
@property (readonly) NSInteger numberOfItems;
@property (readonly) NSInteger indexOfSelectedItem;
@property (nullable, readonly) NSMenuItem *selectedItem;
- (void)addItemWithTitle:(NSString *)title;
- (void)selectItemAtIndex:(NSInteger)index;
- (nullable NSString *)titleOfSelectedItem;
@end

NS_ASSUME_NONNULL_END
