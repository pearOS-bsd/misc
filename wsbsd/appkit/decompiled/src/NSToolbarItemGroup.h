/*
 * NSToolbarItemGroup.h — 1:1 reimplementation (core). NSToolbarItem subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSToolbarItemGroup : NSToolbarItem {
 *       @"NSMutableArray" _groupItems;  q _controlRepresentation;
 *       q _selectionMode;  … _giFlags;
 *   }
 *   -subitems -setSubitems: -selectionMode -setSelectionMode: -selectedIndex
 *   -setSelectedIndex: -setSelected:atIndex: -isSelectedAtIndex:
 *
 * A toolbar item holding a group of subitems with a selection model. SelectOne
 * keeps a single selected index; SelectAny keeps a set; Momentary keeps none.
 * The segmented-control rendering, label-length width adjustment and the
 * group's own image/title are stage2.
 */
#import <Foundation/Foundation.h>
#import "NSToolbarItem.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSToolbarItemGroupSelectionMode) {
    NSToolbarItemGroupSelectionModeSelectOne = 0,
    NSToolbarItemGroupSelectionModeSelectAny = 1,
    NSToolbarItemGroupSelectionModeMomentary = 2,
};

@interface NSToolbarItemGroup : NSToolbarItem

@property (copy) NSArray<NSToolbarItem *> *subitems;
@property NSToolbarItemGroupSelectionMode selectionMode;
@property NSInteger selectedIndex;

- (void)setSelected:(BOOL)selected atIndex:(NSInteger)index;
- (BOOL)isSelectedAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
