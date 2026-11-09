/*
 * NSGridRow.h — 1:1 reimplementation (core). NSObject <NSCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSGridRow : NSObject <NSCoding> {
 *       @"NSGridView" _owningGridView;  @"NSMutableArray" _cells;
 *       @"NSLayoutYAxisAnchor" _top;  q _yPlacement;  q _rowAlignment;
 *       d _height;  d _topPadding;  d _bottomPadding;  B _hidden;
 *   }
 *   -gridView -numberOfCells -cellAtIndex: -yPlacement -rowAlignment -height
 *   -topPadding -bottomPadding -isHidden
 *
 * A row of an NSGridView. Unlike a column, the row owns its cell array, so
 * numberOfCells / cellAtIndex: are exact here; the grid installs the cells via
 * the internal glue. yPlacement/rowAlignment/height/padding/hidden are stored.
 * The layout geometry is stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSGridCell.h"     /* NSGridCellPlacement, NSGridRowAlignment */
#import "NSGridColumn.h"   /* NSGridViewSizeForContent */

NS_ASSUME_NONNULL_BEGIN

@interface NSGridRow : NSObject

@property (nullable, readonly, weak) id gridView;   /* NSGridView */
@property (readonly) NSInteger numberOfCells;
- (NSGridCell *)cellAtIndex:(NSInteger)index;

@property NSGridCellPlacement yPlacement;
@property NSGridRowAlignment rowAlignment;
@property CGFloat height;
@property CGFloat topPadding;
@property CGFloat bottomPadding;
@property (getter=isHidden) BOOL hidden;

/* grid glue (stage2 upstream) */
- (void)_setGridView:(nullable id)gridView;
- (void)_addCell:(NSGridCell *)cell;

@end

NS_ASSUME_NONNULL_END
