/*
 * NSCollectionViewGridLayout.h — 1:1 reimplementation (behavioral core) of
 * AppKit's NSCollectionViewGridLayout (the legacy grid layout :
 * NSCollectionViewLayout).
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSCollectionViewGridLayout_interface.txt. Real ivars: _maxGridRows,
 * _maxGridColumns, _minItemSize, _maxItemSize, _margins, _minimumInteritemSpacing,
 * _minimumLineSpacing, _backgroundColors.
 *
 * Defaults were MEASURED on this Mac by instantiating the real class and reading
 * the properties (probe linking AppKit): every numeric default is 0 / zero size
 * / zero insets, and backgroundColors is empty. This core reproduces that value
 * model and the setter-invalidates contract. The grid geometry solver
 * (_computeGridConfiguration*, prepareLayout, content size, item frames) is
 * TODO(stage2).
 */

#import "NSCollectionViewLayout.h"

NS_ASSUME_NONNULL_BEGIN

@class NSColor;

@interface NSCollectionViewGridLayout : NSCollectionViewLayout

@property NSUInteger maximumNumberOfRows;      /* default 0 (unlimited) */
@property NSUInteger maximumNumberOfColumns;   /* default 0 (unlimited) */
@property NSSize minimumItemSize;              /* default {0,0} */
@property NSSize maximumItemSize;              /* default {0,0} */
@property NSEdgeInsets margins;                /* default {0,0,0,0} */
@property CGFloat minimumInteritemSpacing;     /* default 0 */
@property CGFloat minimumLineSpacing;          /* default 0 */
@property (copy) NSArray<NSColor *> *backgroundColors; /* default empty */

@end

NS_ASSUME_NONNULL_END
