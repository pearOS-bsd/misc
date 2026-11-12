/*
 * NSSecureTextField.h — 1:1 reimplementation (behavioral core) of AppKit's
 * NSSecureTextField, the password-entry text field.
 *
 * Interface evidence (real AppKit.framework, macOS 27 build 26A5416b, arm64e)
 * in evidence/-NSSecureTextField_interface.txt.
 *
 * NSSecureTextField is an NSTextField with no public API of its own; it simply
 * vends an NSSecureTextFieldCell (+cellClass), so input is echoed as bullets.
 * The secure field-editor behaviour lives in the cell (stage2 there).
 */

#import <Foundation/Foundation.h>
#import "NSTextField.h"
#import "NSSecureTextFieldCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface NSSecureTextField : NSTextField
@end

NS_ASSUME_NONNULL_END
