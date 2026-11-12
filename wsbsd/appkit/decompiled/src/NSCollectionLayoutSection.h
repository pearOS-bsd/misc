/*
 * NSCollectionLayoutSection.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSCollectionLayoutSection, a section of a compositional layout.
 *
 * Interface evidence (runtime measurement against real AppKit, macOS 27 build
 * 26A5416b, arm64e — class not emitted in the dyld --objc slices) in
 * evidence/-NSCollectionLayoutSection_interface.txt.
 *
 * This core reproduces construction from a group plus the section configuration
 * (contentInsets, interGroupSpacing, orthogonalScrollingBehavior,
 * supplementariesFollowContentInsets=YES default, boundary/decoration items).
 * The actual group/section solving is the layout engine's job (stage2).
 */

#import <Foundation/Foundation.h>
#import "NSCollectionLayoutGroup.h"
#import "NSCollectionLayoutItem.h"   /* NSDirectionalEdgeInsets */

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSCollectionLayoutSectionOrthogonalScrollingBehavior) {
    NSCollectionLayoutSectionOrthogonalScrollingBehaviorNone = 0,
    NSCollectionLayoutSectionOrthogonalScrollingBehaviorContinuous = 1,
    NSCollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary = 2,
    NSCollectionLayoutSectionOrthogonalScrollingBehaviorPaging = 3,
    NSCollectionLayoutSectionOrthogonalScrollingBehaviorGroupPaging = 4,
    NSCollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered = 5,
};

@interface NSCollectionLayoutSection : NSObject <NSCopying>

+ (instancetype)sectionWithGroup:(NSCollectionLayoutGroup *)group;

@property NSDirectionalEdgeInsets contentInsets;
@property CGFloat interGroupSpacing;
@property NSCollectionLayoutSectionOrthogonalScrollingBehavior orthogonalScrollingBehavior;
@property BOOL supplementariesFollowContentInsets;
@property (copy) NSArray *boundarySupplementaryItems;
@property (copy) NSArray *decorationItems;

@end

NS_ASSUME_NONNULL_END
