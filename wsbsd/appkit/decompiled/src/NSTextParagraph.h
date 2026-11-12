/*
 * NSTextParagraph.h — 1:1 reimplementation (behavioral core) of AppKit/TextKit 2's
 * NSTextParagraph, the NSTextElement that carries one paragraph's attributed text.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSTextParagraph_interface.txt.
 * Real ivars include _attributedString, _paragraphContentRange,
 * _paragraphSeparatorRange (plus bidi/layout caches).
 *
 * This core reproduces the stored model: initWithAttributedString: keeps the
 * SAME attributed string; paragraphContentRange / paragraphSeparatorRange are
 * nil until a content manager assigns them (measured); the element otherwise
 * behaves as its NSTextElement base. Bidi resolution, layout-fragment
 * generation and document synchronisation are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSTextElement.h"

NS_ASSUME_NONNULL_BEGIN

@class NSAttributedString;

@interface NSTextParagraph : NSTextElement

- (instancetype)initWithAttributedString:(nullable NSAttributedString *)attributedString;

@property (readonly, nullable) NSAttributedString *attributedString;
@property (nullable, strong) NSTextRange *paragraphContentRange;
@property (nullable, strong) NSTextRange *paragraphSeparatorRange;

@end

NS_ASSUME_NONNULL_END
