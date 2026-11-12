/*
 * NSCollectionLayoutSupplementaryItem.h — 1:1 reimplementation (behavioral core)
 * of AppKit's NSCollectionLayoutSupplementaryItem, a supplementary item anchored
 * to a container item in a compositional layout.
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionLayoutSupplementaryItem_interface.txt.
 *
 * NSCollectionLayoutSupplementaryItem is an NSCollectionLayoutItem (measured).
 * This core stores the element kind, container/item anchors and zIndex (default
 * 1 — measured), carrying its own layoutSize.
 */

#import <Foundation/Foundation.h>
#import "NSCollectionLayoutItem.h"
#import "NSCollectionLayoutAnchor.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionLayoutSupplementaryItem : NSCollectionLayoutItem

+ (instancetype)supplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                                    elementKind:(NSString *)elementKind
                                containerAnchor:(NSCollectionLayoutAnchor *)containerAnchor;
+ (instancetype)supplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                                    elementKind:(NSString *)elementKind
                                containerAnchor:(NSCollectionLayoutAnchor *)containerAnchor
                                     itemAnchor:(NSCollectionLayoutAnchor *)itemAnchor;

@property NSInteger zIndex;
@property (readonly, copy) NSString *elementKind;
@property (readonly, copy) NSCollectionLayoutAnchor *containerAnchor;
@property (readonly, copy, nullable) NSCollectionLayoutAnchor *itemAnchor;

@end

NS_ASSUME_NONNULL_END
