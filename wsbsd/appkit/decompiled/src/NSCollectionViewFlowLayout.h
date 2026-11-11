/*
 * NSCollectionViewFlowLayout.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSCollectionViewFlowLayout (grid/flow layout : NSCollectionViewLayout).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSCollectionViewFlowLayout_interface.txt. Real ivars include
 * _interitemSpacing, _lineSpacing, _itemSize, _estimatedItemSize,
 * _headerReferenceSize, _footerReferenceSize, _sectionInset, _scrollDirection,
 * _collapsedSectionIndexes, a packed _gridLayoutFlags delegate-cache bitfield,
 * and the _NSFlowLayoutInfo geometry cache (_data).
 *
 * This core reproduces the configuration value model with AppKit's documented
 * defaults, the collapse/expand section bookkeeping, and the standing contract
 * that mutating a layout property invalidates the layout. The actual geometry
 * pass — prepareLayout/_calculateAttributesForRect:/_frameForItem:…/content
 * size, delegate sizing, section floating/pinning, collapse scrolling — is all
 * TODO(stage2) (the _NSFlowLayoutInfo engine).
 */

#import "NSCollectionViewLayout.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSCollectionViewScrollDirection) {
    NSCollectionViewScrollDirectionVertical   = 0,
    NSCollectionViewScrollDirectionHorizontal = 1,
};

@interface NSCollectionViewFlowLayout : NSCollectionViewLayout

@property CGFloat minimumLineSpacing;        /* default 10 */
@property CGFloat minimumInteritemSpacing;   /* default 10 */
@property NSSize  itemSize;                  /* default {50,50} */
@property NSSize  estimatedItemSize;         /* default {0,0} */
@property NSCollectionViewScrollDirection scrollDirection; /* default Vertical */
@property NSSize  headerReferenceSize;       /* default {0,0} */
@property NSSize  footerReferenceSize;       /* default {0,0} */
@property NSEdgeInsets sectionInset;         /* default {0,0,0,0} */
@property BOOL sectionHeadersPinToVisibleBounds;  /* default NO */
@property BOOL sectionFootersPinToVisibleBounds;  /* default NO */

- (void)collapseSectionAtIndex:(NSInteger)index;
- (void)expandSectionAtIndex:(NSInteger)index;
- (BOOL)sectionAtIndexIsCollapsed:(NSUInteger)sectionIndex;

@end

NS_ASSUME_NONNULL_END
