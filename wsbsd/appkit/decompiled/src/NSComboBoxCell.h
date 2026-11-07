/*
 * NSComboBoxCell.h — 1:1 reimplementation (core). NSTextFieldCell subclass.
 * Evidence ../evidence/combo: _cbcFlags @0xe40 — usesDataSource = bit 0,
 * numberOfVisibleItems = halfword at +2 (capped 0xffff). hasVerticalScroller is
 * read off the pop-up scroll view (@0xe34); we keep it as a bool (stage2). The
 * (non-datasource) item list is a separate array.
 */
#import "NSTextFieldCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSComboBoxCell : NSTextFieldCell
@property NSInteger numberOfVisibleItems;
@property BOOL usesDataSource;
@property BOOL hasVerticalScroller;
@property (readonly) NSInteger numberOfItems;
- (void)addItemWithObjectValue:(id)object;
- (id)itemObjectValueAtIndex:(NSInteger)index;
@end

NS_ASSUME_NONNULL_END
