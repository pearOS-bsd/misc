/* NSPathControl.h — 1:1 (core). NSControl backed by NSPathCell; delegates.
 * Evidence ../evidence/path (isEditable 0x1859fe204 -> [cell isEditable]). */
#import "NSControl.h"
#import "NSPathCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSPathControl : NSControl
@property NSPathStyle pathStyle;
@property (nullable, copy) NSURL *URL;
@property (getter=isEditable) BOOL editable;
@end

NS_ASSUME_NONNULL_END
