/* NSSearchField.h — 1:1 (core). NSTextField backed by NSSearchFieldCell; delegates.
 * Evidence ../evidence/search (recentSearches 0x1856aac94 -> cell). */
#import "NSTextField.h"
#import "NSSearchFieldCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSearchField : NSTextField
@property NSInteger maximumRecents;
@property BOOL sendsWholeSearchString;
@property (copy) NSArray<NSString *> *recentSearches;
@end

NS_ASSUME_NONNULL_END
