/*
 * NSCollectionLayoutEdgeSpacing.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSCollectionLayoutEdgeSpacing, per-edge spacing around a layout item.
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionLayoutEdgeSpacing_interface.txt. Fully standalone.
 */

#import <Foundation/Foundation.h>
#import "NSCollectionLayoutSpacing.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionLayoutEdgeSpacing : NSObject <NSCopying>

+ (instancetype)spacingForLeading:(nullable NSCollectionLayoutSpacing *)leading
                              top:(nullable NSCollectionLayoutSpacing *)top
                         trailing:(nullable NSCollectionLayoutSpacing *)trailing
                           bottom:(nullable NSCollectionLayoutSpacing *)bottom;

@property (readonly, nullable) NSCollectionLayoutSpacing *leading;
@property (readonly, nullable) NSCollectionLayoutSpacing *top;
@property (readonly, nullable) NSCollectionLayoutSpacing *trailing;
@property (readonly, nullable) NSCollectionLayoutSpacing *bottom;

@end

NS_ASSUME_NONNULL_END
