/* NSTokenField.h — 1:1 (core). NSTextField backed by NSTokenFieldCell; delegates.
 * Evidence ../evidence/token. */
#import "NSTextField.h"
#import "NSTokenFieldCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSTokenField : NSTextField
@property NSTokenStyle tokenStyle;
@property NSTimeInterval completionDelay;
@property (null_resettable, copy) NSCharacterSet *tokenizingCharacterSet;
@end

NS_ASSUME_NONNULL_END
