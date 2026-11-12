/*
 * NSCollectionLayoutDecorationItem.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSCollectionLayoutDecorationItem, a background decoration item in a
 * compositional layout.
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionLayoutDecorationItem_interface.txt.
 *
 * NSCollectionLayoutDecorationItem is an NSCollectionLayoutItem (measured). This
 * core stores the element kind and zIndex (default 0 — measured).
 */

#import <Foundation/Foundation.h>
#import "NSCollectionLayoutItem.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSCollectionLayoutDecorationItem : NSCollectionLayoutItem

+ (instancetype)backgroundDecorationItemWithElementKind:(NSString *)elementKind;

@property NSInteger zIndex;
@property (readonly, copy) NSString *elementKind;

@end

NS_ASSUME_NONNULL_END
