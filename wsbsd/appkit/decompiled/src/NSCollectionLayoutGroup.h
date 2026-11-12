/*
 * NSCollectionLayoutGroup.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSCollectionLayoutGroup, a container of subitems within a compositional layout.
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionLayoutGroup_interface.txt.
 *
 * NSCollectionLayoutGroup is an NSCollectionLayoutItem (measured). This core
 * reproduces the horizontal/vertical/custom factories, the stored subitems and
 * the group's own layoutSize, plus interItemSpacing. The subitem arrangement
 * (frame solving / custom itemProvider execution) is the layout engine's job
 * (stage2).
 */

#import <Foundation/Foundation.h>
#import "NSCollectionLayoutItem.h"
#import "NSCollectionLayoutSpacing.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionLayoutGroup : NSCollectionLayoutItem

+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                                     subitems:(NSArray<NSCollectionLayoutItem *> *)subitems;
+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                                   subitems:(NSArray<NSCollectionLayoutItem *> *)subitems;

@property (readonly, copy) NSArray<NSCollectionLayoutItem *> *subitems;
@property (nullable, copy) NSCollectionLayoutSpacing *interItemSpacing;

@end

NS_ASSUME_NONNULL_END
