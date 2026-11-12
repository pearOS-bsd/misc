/*
 * NSTextListElement.m — behavioral-1:1 core. See the header.
 */

#import "NSTextListElement.h"

@implementation NSTextListElement {
    NSTextList *_textList;
    NSAttributedString *_contents;
    NSDictionary *_markerAttributes;
    NSArray<NSTextListElement *> *_childElements;
    __weak NSTextListElement *_parentElement;
    NSInteger _nestingLevel;
}

+ (instancetype)textListElementWithContents:(NSAttributedString *)contents
                           markerAttributes:(NSDictionary *)markerAttributes
                                   textList:(NSTextList *)textList
                              childElements:(NSArray<NSTextListElement *> *)children
{
    return [[self alloc] initWithParentElement:nil textList:textList contents:contents
                              markerAttributes:markerAttributes childElements:children];
}

+ (instancetype)textListElementWithChildElements:(NSArray<NSTextListElement *> *)children
                                        textList:(NSTextList *)textList
                                    nestingLevel:(NSInteger)nestingLevel
{
    if (children.count == 0) return nil;   /* a grouping element needs children */
    NSTextListElement *e = [[self alloc] initWithParentElement:nil textList:textList contents:nil
                                              markerAttributes:nil childElements:children];
    e->_nestingLevel = nestingLevel;
    return e;
}

- (instancetype)initWithParentElement:(NSTextListElement *)parent
                             textList:(NSTextList *)textList
                             contents:(NSAttributedString *)contents
                     markerAttributes:(NSDictionary *)markerAttributes
                        childElements:(NSArray<NSTextListElement *> *)children
{
    self = [super initWithAttributedString:contents];
    if (self) {
        _parentElement = parent;
        _textList = textList;
        _contents = contents;
        _markerAttributes = [markerAttributes copy];
        _childElements = [children copy];   /* nil stays nil for a leaf (measured) */
    }
    return self;
}

- (NSTextList *)textList { return _textList; }
- (NSAttributedString *)contents { return _contents; }
- (NSDictionary *)markerAttributes { return _markerAttributes; }
- (NSArray<NSTextListElement *> *)childElements { return _childElements; }
- (NSTextListElement *)parentElement { return _parentElement; }
- (void)setParentElement:(NSTextListElement *)p { _parentElement = p; }

- (BOOL)isRepresentedElement { return YES; }   /* measured */

/* The real class composes "<tab><marker><tab><contents>"; that marker
   formatting is stage2, so the core exposes the raw contents. */
- (NSAttributedString *)attributedString { return _contents; }

@end
