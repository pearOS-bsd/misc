/*
 * NSForm.h — 1:1 reimplementation (behavioral core) of AppKit's NSForm
 * (: NSMatrix), a single-column stack of labelled NSFormCell entries.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSForm_interface.txt.
 *
 * This core reproduces entry management (addEntry:/insertEntry:atIndex:/
 * removeEntryAtIndex:/cellAtIndex:/indexOfCellWithTag:/indexOfSelectedItem) over
 * the NSMatrix cell grid and the bulk title/text setters that fan out to every
 * NSFormCell. Drawing (calcSize/drawCellAtIndex:/sizeToFit geometry) and the
 * field editor (selectTextAtIndex:) are TODO(stage2).
 */

#import "NSMatrix.h"
#import "NSFormCell.h"

NS_ASSUME_NONNULL_BEGIN

@class NSFont;

@interface NSForm : NSMatrix

- (NSFormCell *)addEntry:(NSString *)title;
- (NSFormCell *)insertEntry:(NSString *)title atIndex:(NSInteger)index;
- (void)removeEntryAtIndex:(NSInteger)index;
- (nullable NSFormCell *)cellAtIndex:(NSInteger)index;
- (NSInteger)indexOfCellWithTag:(NSInteger)tag;
- (NSInteger)indexOfSelectedItem;

- (void)setTitleAlignment:(NSTextAlignment)alignment;
- (void)setTextAlignment:(NSTextAlignment)alignment;
- (void)setTitleFont:(NSFont *)font;
- (void)setTextFont:(NSFont *)font;
- (void)setBezeled:(BOOL)flag;
- (void)setBordered:(BOOL)flag;
- (void)setEntryWidth:(CGFloat)width;
- (void)setTitleBaseWritingDirection:(NSWritingDirection)writingDirection;
- (void)setTextBaseWritingDirection:(NSWritingDirection)writingDirection;
- (void)setPreferredTextFieldWidth:(CGFloat)preferredWidth;
- (CGFloat)preferredTextFieldWidth;
- (void)selectTextAtIndex:(NSInteger)index;

@end

NS_ASSUME_NONNULL_END
