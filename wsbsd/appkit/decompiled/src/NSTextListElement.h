/*
 * NSTextListElement.h — 1:1 reimplementation (behavioral core) of AppKit/
 * TextKit 2's NSTextListElement, an NSTextParagraph representing one item (or a
 * grouping) in a text list.
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSTextListElement_interface.txt.
 * Real ivars: _indentLevel, _itemNumber, _contentsOnly, _parentElement (weak),
 * _textList, _contents, _childElements, _markerAttributes, marker-attribute
 * blocks.
 *
 * This core reproduces construction (the two factories + the designated
 * initWithParentElement:textList:contents:markerAttributes:childElements:), the
 * stored accessors (textList/contents/markerAttributes/childElements — all the
 * SAME objects, childElements nil for a leaf — measured) and the overridden
 * parentElement (NSTextListElement, weak). The real -attributedString composes
 * "<tab><marker><tab><contents>" from the list marker + item number; that
 * formatting is TODO(stage2), so -attributedString returns the contents here.
 */

#import <Foundation/Foundation.h>
#import "NSTextParagraph.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTextList, NSTextListElement;

@interface NSTextListElement : NSTextParagraph

+ (instancetype)textListElementWithContents:(NSAttributedString *)contents
                           markerAttributes:(nullable NSDictionary *)markerAttributes
                                   textList:(NSTextList *)textList
                              childElements:(nullable NSArray<NSTextListElement *> *)children;
+ (nullable instancetype)textListElementWithChildElements:(NSArray<NSTextListElement *> *)children
                                                 textList:(NSTextList *)textList
                                             nestingLevel:(NSInteger)nestingLevel;

- (instancetype)initWithParentElement:(nullable NSTextListElement *)parent
                             textList:(NSTextList *)textList
                             contents:(nullable NSAttributedString *)contents
                     markerAttributes:(nullable NSDictionary *)markerAttributes
                        childElements:(nullable NSArray<NSTextListElement *> *)children;

@property (readonly, strong) NSTextList *textList;
@property (readonly, nullable, strong) NSAttributedString *contents;
@property (readonly, nullable, copy) NSDictionary *markerAttributes;
@property (readonly, nullable, copy) NSArray<NSTextListElement *> *childElements;
@property (nullable, weak) NSTextListElement *parentElement;

@end

NS_ASSUME_NONNULL_END
