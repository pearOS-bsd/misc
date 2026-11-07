/*
 * NSTextFieldCell.h — 1:1 reimplementation of AppKit's NSTextFieldCell (core).
 *
 * Inherits NSActionCell (and thus NSCell's bordered/bezeled/editable/selectable
 * flags). Adds the string value. The shipping cell keeps the value in NSCell's
 * _contents via the formatter path; we store it plainly here so the value
 * round-trips (TODO(stage2): _contents + formatter, backgroundColor @0xf2c,
 * _tfFlags @0xf28, drawsBackground).
 */
#import "NSActionCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSTextFieldCell : NSActionCell
@property (copy) NSString *stringValue;
@end

NS_ASSUME_NONNULL_END
