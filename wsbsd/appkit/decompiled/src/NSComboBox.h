/* NSComboBox.h — 1:1 (core). NSTextField backed by NSComboBoxCell; delegates.
 * Evidence ../evidence/combo (numberOfVisibleItems 0x1856a2e5c -> cell). */
#import "NSTextField.h"
#import "NSComboBoxCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSComboBox : NSTextField
@property NSInteger numberOfVisibleItems;
@property BOOL usesDataSource;
@property BOOL hasVerticalScroller;
@property (readonly) NSInteger numberOfItems;
- (void)addItemWithObjectValue:(id)object;
- (id)itemObjectValueAtIndex:(NSInteger)index;
@end

NS_ASSUME_NONNULL_END
