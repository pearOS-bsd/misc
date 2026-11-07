/*
 * NSTextField.h — 1:1 reimplementation of AppKit's NSTextField (core).
 *
 * NSControl subclass backed by NSTextFieldCell. Evidence ../evidence/textfield:
 * isEditable/isSelectable/isBezeled/isBordered all delegate to the cell (loading
 * NSControl._cell and tail-calling the cell). stringValue delegates too.
 */
#import "NSControl.h"
#import "NSTextFieldCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSTextField : NSControl

+ (instancetype)labelWithString:(NSString *)stringValue;

@property (copy) NSString *stringValue;
@property (getter=isEditable) BOOL editable;
@property (getter=isSelectable) BOOL selectable;
@property (getter=isBezeled) BOOL bezeled;
@property (getter=isBordered) BOOL bordered;

@end

NS_ASSUME_NONNULL_END
