/*
 * NSToolbarItemGroup.m — 1:1 (core). See NSToolbarItemGroup.h for the evidence.
 *
 * Holds the subitems and a selection index set governed by selectionMode:
 *   SelectOne   at most one selected; setSelectedIndex: replaces it, and
 *               setSelected:YES atIndex: clears the others first.
 *   SelectAny   any number selected; selectedIndex returns the first selected.
 *   Momentary   no persistent selection; selection calls are ignored.
 * The segmented-control rendering and width adjustment are stage2.
 */
#import "NSToolbarItemGroup.h"

@implementation NSToolbarItemGroup {
    NSMutableArray<NSToolbarItem *> *_subitems;
    NSMutableIndexSet *_selection;
    NSToolbarItemGroupSelectionMode _selectionMode;
}

- (instancetype)initWithItemIdentifier:(NSString *)itemIdentifier
{
    self = [super initWithItemIdentifier:itemIdentifier];
    if (self) {
        _subitems = [NSMutableArray array];
        _selection = [NSMutableIndexSet indexSet];
        _selectionMode = NSToolbarItemGroupSelectionModeSelectOne;
    }
    return self;
}

- (NSArray<NSToolbarItem *> *)subitems { return [_subitems copy]; }
- (void)setSubitems:(NSArray<NSToolbarItem *> *)items
{
    _subitems = [items mutableCopy] ?: [NSMutableArray array];
    [_selection removeAllIndexes];
}

- (NSToolbarItemGroupSelectionMode)selectionMode { return _selectionMode; }
- (void)setSelectionMode:(NSToolbarItemGroupSelectionMode)mode
{
    _selectionMode = mode;
    if (mode == NSToolbarItemGroupSelectionModeMomentary) [_selection removeAllIndexes];
}

- (NSInteger)selectedIndex
{
    return _selection.count ? (NSInteger)_selection.firstIndex : -1;
}

- (void)setSelectedIndex:(NSInteger)index
{
    if (_selectionMode == NSToolbarItemGroupSelectionModeMomentary) return;
    [_selection removeAllIndexes];
    if (index >= 0 && index < (NSInteger)_subitems.count) [_selection addIndex:index];
}

- (void)setSelected:(BOOL)selected atIndex:(NSInteger)index
{
    if (_selectionMode == NSToolbarItemGroupSelectionModeMomentary) return;
    if (index < 0 || index >= (NSInteger)_subitems.count) return;
    if (selected) {
        if (_selectionMode == NSToolbarItemGroupSelectionModeSelectOne)
            [_selection removeAllIndexes];     /* single selection */
        [_selection addIndex:index];
    } else {
        [_selection removeIndex:index];
    }
}

- (BOOL)isSelectedAtIndex:(NSInteger)index
{
    return index >= 0 && [_selection containsIndex:index];
}

@end
