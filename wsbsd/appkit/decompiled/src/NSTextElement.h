/*
 * NSTextElement.h — 1:1 reimplementation (behavioral core) of AppKit/TextKit 2's
 * NSTextElement, the base class for the content pieces a text content manager
 * vends (paragraphs, attachments, …).
 *
 * Interface evidence (real UIFoundation, re-exported by AppKit.framework,
 * macOS 27 build 26A5416b, arm64e) in evidence/-NSTextElement_interface.txt.
 * Real ivars: _textContentManager (weak), _coalescingType, _elementRange.
 *
 * This core reproduces the stored model: initWithTextContentManager: keeps a
 * weak content manager; elementRange (NSTextRange), childElements (empty array
 * by default — measured), parentElement (weak), isRepresentedElement (YES by
 * default — measured), coalescingType. The document-tree traversal and layout
 * estimation are TODO(stage2).
 */

#import <Foundation/Foundation.h>
#import "NSTextRange.h"

NS_ASSUME_NONNULL_BEGIN

@class NSTextContentManager, NSTextElement;

@interface NSTextElement : NSObject

- (instancetype)initWithTextContentManager:(nullable NSTextContentManager *)textContentManager;

@property (nullable, weak) NSTextContentManager *textContentManager;
@property (nullable, strong) NSTextRange *elementRange;
@property (readonly, copy) NSArray<NSTextElement *> *childElements;
@property (readonly, weak, nullable) NSTextElement *parentElement;
@property (readonly) BOOL isRepresentedElement;
@property unsigned char coalescingType;

@end

NS_ASSUME_NONNULL_END
