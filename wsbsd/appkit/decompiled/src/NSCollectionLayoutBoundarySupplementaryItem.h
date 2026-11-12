/*
 * NSCollectionLayoutBoundarySupplementaryItem.h — 1:1 reimplementation
 * (behavioral core) of AppKit's NSCollectionLayoutBoundarySupplementaryItem,
 * a header/footer-style boundary supplementary item.
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionLayoutBoundarySupplementaryItem_interface.txt.
 *
 * NSCollectionLayoutBoundarySupplementaryItem is an NSCollectionLayout-
 * SupplementaryItem (measured). This core stores the alignment + offset and the
 * pinToVisibleBounds (NO) / extendsBoundary (YES) flags.
 */

#import <Foundation/Foundation.h>
#import "NSCollectionLayoutSupplementaryItem.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSRectAlignment) {
    NSRectAlignmentNone = 0,
    NSRectAlignmentTop = 1,
    NSRectAlignmentTopLeading = 2,
    NSRectAlignmentLeading = 3,
    NSRectAlignmentBottomLeading = 4,
    NSRectAlignmentBottom = 5,
    NSRectAlignmentBottomTrailing = 6,
    NSRectAlignmentTrailing = 7,
    NSRectAlignmentTopTrailing = 8,
};

@interface NSCollectionLayoutBoundarySupplementaryItem : NSCollectionLayoutSupplementaryItem

+ (instancetype)boundarySupplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                                            elementKind:(NSString *)elementKind
                                              alignment:(NSRectAlignment)alignment;
+ (instancetype)boundarySupplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize
                                            elementKind:(NSString *)elementKind
                                              alignment:(NSRectAlignment)alignment
                                         absoluteOffset:(CGPoint)absoluteOffset;

@property BOOL extendsBoundary;
@property BOOL pinToVisibleBounds;
@property (readonly) NSRectAlignment alignment;
@property (readonly) CGPoint offset;

@end

NS_ASSUME_NONNULL_END
