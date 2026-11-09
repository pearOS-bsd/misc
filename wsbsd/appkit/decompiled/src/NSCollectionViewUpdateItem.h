/*
 * NSCollectionViewUpdateItem.h — 1:1 reimplementation (core). NSObject <NSCopying>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSCollectionViewUpdateItem : NSObject <NSCopying> {
 *       @"NSIndexPath" _initialIndexPath;  @"NSIndexPath" _finalIndexPath;
 *       q _updateAction;  @"NSUUID" _identifier;  …
 *   }
 *   -updateAction -indexPathBeforeUpdate -indexPathAfterUpdate
 *   -initWithOldIndexPath:newIndexPath:
 *
 * Describes a single insert/delete/move/reload in a collection-view batch
 * update. initWithOldIndexPath:newIndexPath: infers the action from which paths
 * are present. The animation driving these updates is stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSCollectionUpdateAction) {
    NSCollectionUpdateActionInsert = 0,
    NSCollectionUpdateActionDelete = 1,
    NSCollectionUpdateActionReload = 2,
    NSCollectionUpdateActionMove = 3,
    NSCollectionUpdateActionNone = 4,
};

@interface NSCollectionViewUpdateItem : NSObject <NSCopying>

- (instancetype)initWithOldIndexPath:(nullable NSIndexPath *)oldIndexPath
                        newIndexPath:(nullable NSIndexPath *)newIndexPath;

@property (nullable, readonly) NSIndexPath *indexPathBeforeUpdate;
@property (nullable, readonly) NSIndexPath *indexPathAfterUpdate;
@property (readonly) NSCollectionUpdateAction updateAction;

@end

NS_ASSUME_NONNULL_END
