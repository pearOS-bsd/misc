/*
 * NSMenu.m — 1:1 reimplementation of AppKit's NSMenu (core).
 * Addresses cite the macOS 27 arm64e disassembly under ../evidence/menu.
 *
 * Shipping ivars: _title at 0x10, _itemArray (NSMutableArray) at 0x18.
 */
#import "NSMenu.h"
#import "NSMenuItem.h"

@implementation NSMenu {
    NSString *_title;                      /* 0x10 */
    NSMutableArray<NSMenuItem *> *_items;   /* 0x18 */
}

/* -[NSMenu initWithTitle:]  — evidence: 0x184ef3f8c */
- (instancetype)initWithTitle:(NSString *)title
{
    self = [super init];
    if (self) {
        _title = [title copy] ?: @"";
        _items = [NSMutableArray array];
    }
    return self;
}

- (instancetype)init { return [self initWithTitle:@""]; }

/* -[NSMenu title] 0x184ef2dc4 / setTitle: 0x18510fdf0 (early-out on isEqual). */
- (NSString *)title { return _title; }
- (void)setTitle:(NSString *)title
{
    if ([_title isEqualToString:title])
        return;
    _title = [title copy] ?: @"";
}

/* -[NSMenu numberOfItems] 0x184eee018  ([_items count]). */
- (NSInteger)numberOfItems { return (NSInteger)_items.count; }

/* -[NSMenu itemArray] 0x184eedc48 (a copy of the internal storage). */
- (NSArray<NSMenuItem *> *)itemArray { return [_items copy]; }

/* -[NSMenu itemAtIndex:] 0x184eee020 (bounds-checked). */
- (NSMenuItem *)itemAtIndex:(NSInteger)index
{
    if (index < 0 || (NSUInteger)index >= _items.count)
        [NSException raise:NSRangeException format:@"index %ld beyond bounds", (long)index];
    return _items[(NSUInteger)index];
}

/* -[NSMenu addItem:] 0x184ef0d50  -> insertItem:atIndex:numberOfItems. */
- (void)addItem:(NSMenuItem *)newItem { [self insertItem:newItem atIndex:(NSInteger)_items.count]; }

/* -[NSMenu insertItem:atIndex:] 0x184ef0d98
 * Core insert. TODO(stage2): main-thread assertion, NSMenuDidAddItem
 * notification, and setting newItem.menu back to self. */
- (void)insertItem:(NSMenuItem *)newItem atIndex:(NSInteger)index
{
    if (!newItem)
        return;
    if (index < 0 || (NSUInteger)index > _items.count)
        [NSException raise:NSRangeException format:@"insert index %ld out of range", (long)index];
    [_items insertObject:newItem atIndex:(NSUInteger)index];
}

/* -[NSMenu indexOfItem:] 0x184ef1ce0  (-1 when absent, matching the binary). */
- (NSInteger)indexOfItem:(NSMenuItem *)item
{
    NSUInteger idx = [_items indexOfObjectIdenticalTo:item];
    return (idx == NSNotFound) ? -1 : (NSInteger)idx;
}

/* -[NSMenu removeItemAtIndex:] 0x184f046fc. */
- (void)removeItemAtIndex:(NSInteger)index
{
    if (index < 0 || (NSUInteger)index >= _items.count)
        return;
    [_items removeObjectAtIndex:(NSUInteger)index];
}

/* -[NSMenu removeItem:]. */
- (void)removeItem:(NSMenuItem *)item
{
    NSInteger idx = [self indexOfItem:item];
    if (idx >= 0)
        [self removeItemAtIndex:idx];
}

/* -[NSMenu itemWithTitle:] / itemWithTag:  (first match). */
- (NSMenuItem *)itemWithTitle:(NSString *)title
{
    for (NSMenuItem *it in _items)
        if ([it.title isEqualToString:title])
            return it;
    return nil;
}
- (NSMenuItem *)itemWithTag:(NSInteger)tag
{
    for (NSMenuItem *it in _items)
        if (it.tag == tag)
            return it;
    return nil;
}

/* -[NSMenu addItemWithTitle:action:keyEquivalent:]  (build an item, add, return). */
- (NSMenuItem *)addItemWithTitle:(NSString *)title action:(SEL)action keyEquivalent:(NSString *)keyEquivalent
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:keyEquivalent];
    [self addItem:item];
    return item;
}

@end
