/*
 * NSTableColumn.h — 1:1 reimplementation (core). NSObject.
 * Evidence ../evidence/tablecol: _identifier 0x10, _width 0x18, _maxWidth 0x58,
 * editable = flags 0x48 bit 1; setWidth: clamps to [minWidth, maxWidth]. The
 * title lives in a headerCell (stage2, kept plainly here).
 */
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSTableColumn : NSObject
- (instancetype)initWithIdentifier:(NSString *)identifier;
@property (copy) NSString *identifier;
@property CGFloat width;
@property CGFloat minWidth;
@property CGFloat maxWidth;
@property (copy) NSString *title;
@property (getter=isEditable) BOOL editable;
@end

NS_ASSUME_NONNULL_END
