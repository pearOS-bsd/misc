/*
 * NSTableView.h — 1:1 reimplementation (core). NSControl subclass.
 * Evidence ../evidence/table: _tableColumns @0xefc, _tvFlags @0xf08
 * (allowsColumnReordering = bit 31). numberOfColumns = [columns count].
 * Row content is data-source/delegate driven and view-based — stage2; this pass
 * covers column management and the simple geometry/flags.
 */
#import "NSControl.h"
#import "NSTableColumn.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSTableView : NSControl
- (void)addTableColumn:(NSTableColumn *)column;
- (void)removeTableColumn:(NSTableColumn *)column;
@property (readonly, copy) NSArray<NSTableColumn *> *tableColumns;
@property (readonly) NSInteger numberOfColumns;
- (nullable NSTableColumn *)columnWithIdentifier:(NSString *)identifier; /* actually -tableColumnWithIdentifier: in modern API */
- (NSInteger)columnIndexWithIdentifier:(NSString *)identifier;
@property CGFloat rowHeight;
@property BOOL allowsColumnReordering;
@end

NS_ASSUME_NONNULL_END
