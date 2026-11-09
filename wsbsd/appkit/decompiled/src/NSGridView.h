/*
 * NSGridView.h — 1:1 reimplementation (core). NSView subclass.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSGridView : NSView {
 *       q _xPlacement; q _yPlacement; q _rowAlignment; d _rowSpacing; d _colSpacing;
 *       @"NSMutableArray" _columns; @"NSMutableArray" _rows; @"NSMapTable" _cellTable; …
 *   }
 *   -numberOfRows -numberOfColumns -rowAtIndex: -columnAtIndex:
 *   -cellAtColumnIndex:rowIndex: -addRowWithViews: -addColumnWithViews:
 *   -rowSpacing -columnSpacing -xPlacement -yPlacement -rowAlignment
 *
 * The grid container. addRowWithViews: builds an NSGridRow of cells (one per
 * view) and grows the column list to match; cellAtColumnIndex:rowIndex: indexes
 * the cell matrix. The actual Auto Layout solving of cell frames is stage2; the
 * matrix bookkeeping here is exact.
 */
#import <Foundation/Foundation.h>
#import "NSView.h"
#import "NSGridCell.h"
#import "NSGridRow.h"
#import "NSGridColumn.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSGridView : NSView

@property (readonly) NSInteger numberOfRows;
@property (readonly) NSInteger numberOfColumns;
@property NSGridCellPlacement xPlacement;
@property NSGridCellPlacement yPlacement;
@property NSGridRowAlignment rowAlignment;
@property CGFloat rowSpacing;
@property CGFloat columnSpacing;

- (NSGridRow *)rowAtIndex:(NSInteger)index;
- (NSGridColumn *)columnAtIndex:(NSInteger)index;
- (NSGridCell *)cellAtColumnIndex:(NSInteger)columnIndex rowIndex:(NSInteger)rowIndex;

- (NSGridRow *)addRowWithViews:(NSArray<NSView *> *)views;
- (NSGridColumn *)addColumnWithViews:(NSArray<NSView *> *)views;

@end

NS_ASSUME_NONNULL_END
