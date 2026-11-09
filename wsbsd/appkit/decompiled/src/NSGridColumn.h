/*
 * NSGridColumn.h — 1:1 reimplementation (core). NSObject <NSCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSGridColumn : NSObject <NSCoding> {
 *       @"NSGridView" _owningGridView;  @"NSLayoutXAxisAnchor" _leading;
 *       q _xPlacement;  d _width;  d _trailingPadding;  d _leadingPadding;
 *       B _hidden;
 *   }
 *   -gridView -xPlacement -width -leadingPadding -trailingPadding -isHidden -index
 *
 * A column of an NSGridView. The core holds the (weak) owning grid, the column
 * placement, width (default the size-for-content sentinel), leading/trailing
 * padding and the hidden flag. numberOfCells / cellAtIndex: / index depend on
 * the grid's cell matrix and are stage2.
 */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "NSGridCell.h"   /* NSGridCellPlacement */

NS_ASSUME_NONNULL_BEGIN

static const CGFloat NSGridViewSizeForContent = -1.0;   /* width/height sentinel */

@interface NSGridColumn : NSObject

@property (nullable, readonly, weak) id gridView;   /* NSGridView */
@property NSGridCellPlacement xPlacement;
@property CGFloat width;
@property CGFloat leadingPadding;
@property CGFloat trailingPadding;
@property (getter=isHidden) BOOL hidden;

/* grid glue installs the owning grid (stage2 upstream). */
- (void)_setGridView:(nullable id)gridView;

@end

NS_ASSUME_NONNULL_END
