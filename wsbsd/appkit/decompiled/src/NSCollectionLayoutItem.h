/*
 * NSCollectionLayoutItem.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSCollectionLayoutItem, a leaf item in a compositional collection-view layout.
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionLayoutItem_interface.txt.
 *
 * This core reproduces construction (itemWithLayoutSize: COPIES the size —
 * measured), contentInsets (zero default, settable), edgeSpacing (nullable) and
 * supplementaryItems. The actual frame solving is done by the layout engine
 * (stage2) and is not part of this value object.
 */

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSCollectionLayoutSize.h"
#import "NSCollectionLayoutEdgeSpacing.h"

NS_ASSUME_NONNULL_BEGIN

#ifndef NSDIRECTIONALEDGEINSETS_DEFINED
#define NSDIRECTIONALEDGEINSETS_DEFINED
typedef struct NSDirectionalEdgeInsets {
    CGFloat top, leading, bottom, trailing;
} NSDirectionalEdgeInsets;
static inline NSDirectionalEdgeInsets NSDirectionalEdgeInsetsMake(CGFloat top, CGFloat leading, CGFloat bottom, CGFloat trailing) {
    NSDirectionalEdgeInsets i; i.top = top; i.leading = leading; i.bottom = bottom; i.trailing = trailing; return i;
}
extern const NSDirectionalEdgeInsets NSDirectionalEdgeInsetsZero;
#endif

@interface NSCollectionLayoutItem : NSObject <NSCopying>

+ (instancetype)itemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize;
+ (instancetype)itemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                 supplementaryItems:(NSArray *)supplementaryItems;

@property (readonly, copy) NSCollectionLayoutSize *layoutSize;
@property NSDirectionalEdgeInsets contentInsets;
@property (nullable, copy) NSCollectionLayoutEdgeSpacing *edgeSpacing;
@property (readonly, copy) NSArray *supplementaryItems;

@end

NS_ASSUME_NONNULL_END
