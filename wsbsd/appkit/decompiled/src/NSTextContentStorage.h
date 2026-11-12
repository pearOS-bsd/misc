/*
 * NSTextContentStorage.h — 1:1 reimplementation (behavioral core) of AppKit/
 * TextKit 2's NSTextContentStorage, the concrete NSTextContentManager backed by
 * an attributed string.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSTextContentStorage_interface.txt.
 *
 * This core reproduces the integer-offset content model: attributedString
 * (settable, empty by default — measured), documentRange spanning
 * 0…attributedString.length over integer NSTextLocations,
 * offsetFromLocation:toLocation: / locationFromLocation:withOffset: arithmetic,
 * textElementsForRange: splitting the text into one NSTextParagraph per
 * paragraph (measured: "ab\\ncd" -> 2 paragraphs), and attributedStringForText-
 * Element:. Live NSTextStorage observation, anchored attachments and layout
 * synchronisation are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSTextContentManager.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTextParagraph;

@interface NSTextContentStorage : NSTextContentManager

@property (nullable, copy) NSAttributedString *attributedString;

- (nullable NSAttributedString *)attributedStringForTextElement:(NSTextElement *)textElement;
- (nullable NSTextElement *)textParagraphForLocation:(id<NSTextLocation>)location;

- (nullable id<NSTextLocation>)locationFromLocation:(id<NSTextLocation>)location withOffset:(NSInteger)offset;
- (NSInteger)offsetFromLocation:(id<NSTextLocation>)from toLocation:(id<NSTextLocation>)to;

@end

/* integer-offset NSTextLocation used by the storage (NSCountableTextRange-like) */
@interface NSTextContentStorageLocation : NSObject <NSTextLocation>
@property (readonly) NSInteger offset;
+ (instancetype)locationWithOffset:(NSInteger)offset;
@end

NS_ASSUME_NONNULL_END
