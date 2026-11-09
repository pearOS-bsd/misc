/*
 * NSTextTable.h — 1:1 reimplementation (core). NSTextBlock subclass.
 * Public AppKit text API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSTextTable : NSTextBlock <NSSecureCoding> {
 *       Q _numCols;  Q _tableFlags;
 *   }
 *   @property (Tq) numberOfColumns;  (Tq) layoutAlgorithm;
 *   @property (TB) collapsesBorders;  (TB) hidesEmptyCells;
 *
 * The table a group of NSTextTableBlocks belongs to. The core stores the column
 * count, the layout algorithm and the collapse/hide flags (_tableFlags). The
 * table rect/column sizing (rectForBlock:…) is stage2.
 */
#import <Foundation/Foundation.h>
#import "NSTextBlock.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSTextTableLayoutAlgorithm) {
    NSTextTableAutomaticLayoutAlgorithm = 0,
    NSTextTableFixedLayoutAlgorithm = 1,
};

@interface NSTextTable : NSTextBlock

@property NSUInteger numberOfColumns;
@property NSTextTableLayoutAlgorithm layoutAlgorithm;
@property BOOL collapsesBorders;
@property BOOL hidesEmptyCells;

@end

NS_ASSUME_NONNULL_END
