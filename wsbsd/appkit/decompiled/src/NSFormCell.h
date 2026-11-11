/*
 * NSFormCell.h — 1:1 reimplementation (behavioral core) of AppKit's NSFormCell
 * (: NSActionCell), one labelled row of a legacy NSForm.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSFormCell_interface.txt. Real ivars: _titleWidth, _titleEndPoint,
 * _preferredTextFieldWidth, _titleCell.
 *
 * Defaults MEASURED on this Mac: titleAlignment Right(2), titleBaseWritingDirection
 * Natural(-1), preferredTextFieldWidth -1, placeholder nil; titleWidth with no
 * explicit value auto-sizes to the title text width (font metrics) — reproduced
 * here as the -1 auto sentinel, the measured width computation is stage2.
 */

#import "NSActionCell.h"

NS_ASSUME_NONNULL_BEGIN

@class NSFont, NSAttributedString;

/* Modern NSTextAlignment / NSWritingDirection values (as the SDK defines them). */
#ifndef NSTextAlignment_FormCell_defined
#define NSTextAlignment_FormCell_defined
typedef NS_ENUM(NSInteger, NSTextAlignment) {
    NSTextAlignmentLeft      = 0,
    NSTextAlignmentCenter    = 1,
    NSTextAlignmentRight     = 2,
    NSTextAlignmentJustified = 3,
    NSTextAlignmentNatural   = 4,
};
typedef NS_ENUM(NSInteger, NSWritingDirection) {
    NSWritingDirectionNatural     = -1,
    NSWritingDirectionLeftToRight = 0,
    NSWritingDirectionRightToLeft = 1,
};
#endif

@interface NSFormCell : NSActionCell

- (instancetype)initTextCell:(nullable NSString *)string;

@property (copy) NSString *title;
@property (nullable, strong) NSFont *titleFont;
@property CGFloat titleWidth;                        /* default -1 (auto) */
@property NSTextAlignment titleAlignment;            /* default Right */
@property NSWritingDirection titleBaseWritingDirection; /* default Natural */
@property (nullable, copy) NSString *placeholderString;
@property (nullable, copy) NSAttributedString *placeholderAttributedString;
@property CGFloat preferredTextFieldWidth;           /* default -1 */
@property (nullable, copy) NSAttributedString *attributedTitle;

@end

NS_ASSUME_NONNULL_END
