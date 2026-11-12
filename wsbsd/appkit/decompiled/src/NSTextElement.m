/*
 * NSTextElement.m — behavioral-1:1 core. See the header.
 */

#import "NSTextElement.h"

@implementation NSTextElement {
    __weak NSTextContentManager *_textContentManager;
    NSTextRange *_elementRange;
    NSMutableArray<NSTextElement *> *_childElements;
    __weak NSTextElement *_parentElement;
    unsigned char _coalescingType;
}

- (instancetype)init { return [self initWithTextContentManager:nil]; }

- (instancetype)initWithTextContentManager:(NSTextContentManager *)textContentManager
{
    self = [super init];
    if (self) {
        _textContentManager = textContentManager;
        _childElements = [NSMutableArray array];
    }
    return self;
}

- (NSTextContentManager *)textContentManager { return _textContentManager; }
- (void)setTextContentManager:(NSTextContentManager *)m { _textContentManager = m; }
- (NSTextRange *)elementRange { return _elementRange; }
- (void)setElementRange:(NSTextRange *)r { _elementRange = r; }
- (NSArray<NSTextElement *> *)childElements { return [_childElements copy]; }
- (NSTextElement *)parentElement { return _parentElement; }
- (BOOL)isRepresentedElement { return YES; }   /* measured default */
- (unsigned char)coalescingType { return _coalescingType; }
- (void)setCoalescingType:(unsigned char)t { _coalescingType = t; }

/* internal tree wiring used by content managers / subclasses (not public API). */
- (void)_addChildElement:(NSTextElement *)child
{
    if (!child || [_childElements containsObject:child]) return;
    [_childElements addObject:child];
    child->_parentElement = self;
}

@end
