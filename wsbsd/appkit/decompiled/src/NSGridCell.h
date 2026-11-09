/*
 * NSGridCell.h — 1:1 reimplementation (core). NSObject <NSCoding>.
 *
 * Evidence: interface from the dyld shared cache (AppKit, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … AppKit --objc`:
 *
 *   @interface NSGridCell : NSObject <NSCoding> {
 *       @"NSGridRow" _row;  @"NSGridColumn" _column;  @"NSView" _contentView;
 *       @"NSGridCell" _headOfMergedCell;  q _xPlacement;  q _yPlacement;
 *       q _rowAlignment;
 *   }
 *   -contentView -setContentView: -row -column -xPlacement -yPlacement -rowAlignment
 *
 * One cell of an NSGridView. The core holds the content view, the owning row/
 * column back-links and the placement/alignment. Cell merging and the grid
 * layout geometry are stage2.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class NSView;

typedef NS_ENUM(NSInteger, NSGridCellPlacement) {
    NSGridCellPlacementInherited = 0,
    NSGridCellPlacementNone = 1,
    NSGridCellPlacementLeading = 2,
    NSGridCellPlacementTop = 2,
    NSGridCellPlacementTrailing = 3,
    NSGridCellPlacementBottom = 3,
    NSGridCellPlacementCenter = 4,
    NSGridCellPlacementFill = 5,
};

typedef NS_ENUM(NSInteger, NSGridRowAlignment) {
    NSGridRowAlignmentInherited = 0,
    NSGridRowAlignmentNone = 1,
    NSGridRowAlignmentFirstBaseline = 2,
    NSGridRowAlignmentLastBaseline = 3,
};

@interface NSGridCell : NSObject

@property (nullable, strong) NSView *contentView;
@property (nullable, readonly, weak) id row;      /* NSGridRow */
@property (nullable, readonly, weak) id column;   /* NSGridColumn */
@property NSGridCellPlacement xPlacement;
@property NSGridCellPlacement yPlacement;
@property NSGridRowAlignment rowAlignment;

/* grid glue sets the owning row/column (stage2 upstream). */
- (void)_setRow:(nullable id)row;
- (void)_setColumn:(nullable id)column;

@end

NS_ASSUME_NONNULL_END
