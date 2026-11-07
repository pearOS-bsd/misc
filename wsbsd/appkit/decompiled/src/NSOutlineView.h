/*
 * NSOutlineView.h — 1:1 reimplementation (core). NSTableView subclass.
 * Evidence ../evidence/outline: indentationPerLevel is stored as an integer and
 * returned as a double (scvtf); setter truncates and clamps >= 0.
 * outlineTableColumn is an ivar; autoresizesOutlineColumn is flags bit 3.
 * Item expansion / data-source tree is stage2.
 */
#import "NSTableView.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSOutlineView : NSTableView
@property CGFloat indentationPerLevel;
@property (nullable, strong) NSTableColumn *outlineTableColumn;
@property BOOL autoresizesOutlineColumn;
@end

NS_ASSUME_NONNULL_END
