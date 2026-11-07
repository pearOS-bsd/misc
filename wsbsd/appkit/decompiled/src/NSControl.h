/*
 * NSControl.h — 1:1 reimplementation of AppKit's NSControl (cell-backed core).
 *
 * Shape from ../reference/NSControl.h; logic from ../evidence/nscontrol.
 * NSControl is a thin delegator to its cell: nearly every accessor is
 *   _NSControlDelegatesToCell(self) ? [cell sel] : <_conFlags/_controlStorage>.
 *
 * Shipped now: cell management, isEnabled, and target/action/tag delegation to
 * the (action) cell. Staged (delegate to NSCell value/font/continuous, which are
 * themselves stage2, or route through NSApp): stringValue/intValue/objectValue,
 * font, isContinuous, performClick:, sendAction:to:. Marked TODO(stage2) in .m.
 */
#import "NSView.h"
#import "NSCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSControl : NSView

+ (nullable Class)cellClass;

@property (nullable, strong) __kindof NSCell *cell;
@property (getter=isEnabled) BOOL enabled;
@property (nullable, weak) id target;
@property (nullable) SEL action;
@property NSInteger tag;

- (BOOL)sendAction:(nullable SEL)action to:(nullable id)target;

@end

NS_ASSUME_NONNULL_END
