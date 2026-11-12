/*
 * NSCollectionLayoutSize.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSCollectionLayoutSize, a width+height pair of NSCollectionLayoutDimensions.
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionLayoutSize_interface.txt.
 *
 * Fully standalone value object; +sizeWithWidthDimension:heightDimension:
 * stores both dimensions, exposed readonly, with NSCopying.
 */

#import <Foundation/Foundation.h>
#import "NSCollectionLayoutDimension.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionLayoutSize : NSObject <NSCopying>

+ (instancetype)sizeWithWidthDimension:(NSCollectionLayoutDimension *)width
                       heightDimension:(NSCollectionLayoutDimension *)height;

@property (readonly, copy) NSCollectionLayoutDimension *widthDimension;
@property (readonly, copy) NSCollectionLayoutDimension *heightDimension;

@end

NS_ASSUME_NONNULL_END
