/*
 * NSCell.h — 1:1 reimplementation of AppKit's NSCell (flag/state core).
 *
 * Class shape from the real AppKit.framework on macOS 27 (arm64e),
 * ../reference/NSCell.h. Method logic from the ../evidence/nscell files; see .m.
 *
 * Shipped now (fully decoded from the _cFlags bitfield at ivar offset 0x10):
 *   state/setState:, isHighlighted/setHighlighted:, isEnabled/setEnabled:,
 *   type/setType:, and the target/action/tag throwing stubs (these really live
 *   in NSActionCell — NSCell's own setters raise).
 *
 * Staged (need the _contents + formatter helper tree, and NSApp, decoded first):
 *   objectValue/stringValue/intValue/title and the designated initialisers'
 *   control-tint setup. Marked TODO(stage2) in the .m.
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSCellType) {
    NSNullCellType  = 0,
    NSTextCellType  = 1,
    NSImageCellType = 2,
};

/* NSControl.state values; NSControlStateValueMixed == -1. */
typedef NSInteger NSControlStateValue;
static const NSControlStateValue NSControlStateValueMixed = -1;
static const NSControlStateValue NSControlStateValueOff   = 0;
static const NSControlStateValue NSControlStateValueOn    = 1;

@interface NSCell : NSObject

@property NSControlStateValue state;
@property (getter=isEnabled) BOOL enabled;
@property (getter=isHighlighted) BOOL highlighted;
@property NSCellType type;
@property (getter=isBordered) BOOL bordered;
@property (getter=isBezeled) BOOL bezeled;
@property (getter=isEditable) BOOL editable;
@property (getter=isSelectable) BOOL selectable;

/* NSCell's own target/action/tag are stubs (see NSActionCell for the real ones). */
@property (nullable, weak) id target;
@property (nullable) SEL action;
@property NSInteger tag;

@end

NS_ASSUME_NONNULL_END
