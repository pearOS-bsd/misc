/*
 * NSSecureTextFieldCell.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSSecureTextFieldCell, the cell behind a secure (password) text field.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSSecureTextFieldCell_interface.txt.
 *
 * NSSecureTextFieldCell is an NSTextFieldCell (measured). This core adds the
 * echosBullets flag (YES by default — measured). The secure field editor
 * (bullet echo, disabled copy, secure input mode) is TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSTextFieldCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSecureTextFieldCell : NSTextFieldCell

- (instancetype)initTextCell:(NSString *)string;

@property BOOL echosBullets;

@end

NS_ASSUME_NONNULL_END
