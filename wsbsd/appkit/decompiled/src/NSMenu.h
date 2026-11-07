/*
 * NSMenu.h — 1:1 reimplementation of AppKit's NSMenu (core).
 *
 * Shape from ../reference/NSMenu.h; logic from ../evidence/menu. NSMenu keeps
 * its title at ivar 0x10 and its items in an internal mutable array at 0x18.
 * Shipped: title, the item array and insert/remove/lookup. Staged: the
 * insertItem:atIndex: main-thread check, the NSMenuDidAdd/RemoveItem
 * notifications and the item.menu back-link. TODO(stage2) in the .m.
 */
#import <Foundation/Foundation.h>

@class NSMenuItem;

NS_ASSUME_NONNULL_BEGIN

@interface NSMenu : NSObject

- (instancetype)initWithTitle:(NSString *)title;

@property (copy) NSString *title;
@property (readonly) NSArray<NSMenuItem *> *itemArray;
@property (readonly) NSInteger numberOfItems;

- (void)addItem:(NSMenuItem *)newItem;
- (void)insertItem:(NSMenuItem *)newItem atIndex:(NSInteger)index;
- (void)removeItem:(NSMenuItem *)item;
- (void)removeItemAtIndex:(NSInteger)index;

- (NSMenuItem *)itemAtIndex:(NSInteger)index;
- (NSInteger)indexOfItem:(NSMenuItem *)item;
- (nullable NSMenuItem *)itemWithTitle:(NSString *)title;
- (nullable NSMenuItem *)itemWithTag:(NSInteger)tag;

- (NSMenuItem *)addItemWithTitle:(NSString *)title
                          action:(nullable SEL)action
                   keyEquivalent:(NSString *)keyEquivalent;

@end

NS_ASSUME_NONNULL_END
