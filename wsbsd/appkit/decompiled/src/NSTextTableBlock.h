/*
 * NSTextTableBlock.h — 1:1 reimplementation (core). NSTextBlock subclass.
 * Public AppKit text API; ships in UIFoundation in the shared cache.
 *
 * Evidence: interface from the dyld shared cache (UIFoundation, macOS 26A5416b,
 * arm64e) via `ipsw dyld macho … UIFoundation --objc`:
 *
 *   @interface NSTextTableBlock : NSTextBlock <NSSecureCoding> {
 *       @"NSTextTable" _table;  q _rowNum;  q _colNum;  q _rowSpan;  q _colSpan;
 *   }
 *   -initWithTable:startingRow:rowSpan:startingColumn:columnSpan:
 *   -table -startingRow -rowSpan -startingColumn -columnSpan
 *
 * A single cell of an NSTextTable. The core holds the owning table and the
 * (row, rowSpan, column, columnSpan) placement, inheriting NSTextBlock's
 * dimension/border/background. The block layout is stage2.
 */
#import <Foundation/Foundation.h>
#import "NSTextBlock.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTextTable;

@interface NSTextTableBlock : NSTextBlock

- (instancetype)initWithTable:(NSTextTable *)table
                  startingRow:(NSInteger)row rowSpan:(NSInteger)rowSpan
               startingColumn:(NSInteger)col columnSpan:(NSInteger)colSpan;

@property (readonly, strong) NSTextTable *table;
@property (readonly) NSInteger startingRow;
@property (readonly) NSInteger rowSpan;
@property (readonly) NSInteger startingColumn;
@property (readonly) NSInteger columnSpan;

@end

NS_ASSUME_NONNULL_END
