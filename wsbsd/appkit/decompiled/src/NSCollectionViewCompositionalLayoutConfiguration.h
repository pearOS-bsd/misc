/*
 * NSCollectionViewCompositionalLayoutConfiguration.h — 1:1 reimplementation
 * (behavioral core) of AppKit's NSCollectionViewCompositionalLayoutConfiguration,
 * the global configuration of a compositional collection-view layout.
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionViewCompositionalLayoutConfiguration_interface.txt.
 * Fully standalone value object.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSCollectionViewFlowLayout.h"   /* NSCollectionViewScrollDirection */

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionViewCompositionalLayoutConfiguration : NSObject <NSCopying>

@property NSCollectionViewScrollDirection scrollDirection;
@property CGFloat interSectionSpacing;
@property (copy) NSArray *boundarySupplementaryItems;

@end

NS_ASSUME_NONNULL_END
