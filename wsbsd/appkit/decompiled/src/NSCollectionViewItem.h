/*
 * NSCollectionViewItem.h — 1:1 reimplementation (core). NSViewController subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSCollectionViewItem : NSViewController <NSCopying,
 *                                                        NSCollectionViewElement> {
 *       {?="isSelected"b1 …"highlightState"b2 …} _cviFlags;  @"NSData" _cachedArchive;
 *   }
 *   @property (T@"NSCollectionView",R,W) collectionView;  (TB,GisSelected) selected;
 *   @property (Tq) highlightState;  (T@"NSImageView",W) imageView;
 *   @property (T@"NSTextField",W) textField;
 *
 * Represents one item view in an NSCollectionView. The core tracks the selected
 * and highlightState flags (_cviFlags bits) plus the collectionView back-link
 * and the imageView/textField outlets. Dragging image components, reuse/dequeue
 * bookkeeping and the nib archive are stage2.
 */
#import <Foundation/Foundation.h>
#import "NSViewController.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSCollectionViewItemHighlightState) {
    NSCollectionViewItemHighlightNone = 0,
    NSCollectionViewItemHighlightForSelection = 1,
    NSCollectionViewItemHighlightForDeselection = 2,
    NSCollectionViewItemHighlightAsDropTarget = 3,
};

@interface NSCollectionViewItem : NSViewController

@property (nullable, weak) id collectionView;
@property (getter=isSelected) BOOL selected;
@property NSCollectionViewItemHighlightState highlightState;
@property (nullable, weak) id imageView;
@property (nullable, weak) id textField;

@end

NS_ASSUME_NONNULL_END
