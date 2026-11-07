/*
 * NSPathCell.h — 1:1 reimplementation (core). NSActionCell subclass.
 * Evidence ../evidence/path: pathStyle @0xa08; URL routes through the cell
 * contents (kept plainly here, stage2). pathItems / drawing are stage2.
 */
#import "NSActionCell.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, NSPathStyle) {
    NSPathStyleStandard = 0,
    NSPathStylePopUp = 2,
};

@interface NSPathCell : NSActionCell
@property NSPathStyle pathStyle;
@property (nullable, copy) NSURL *URL;
@end

NS_ASSUME_NONNULL_END
