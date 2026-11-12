/*
 * NSTextParagraph.m — behavioral-1:1 core. See the header.
 */

#import "NSTextParagraph.h"

@implementation NSTextParagraph {
    NSAttributedString *_attributedString;
    NSTextRange *_paragraphContentRange;
    NSTextRange *_paragraphSeparatorRange;
}

- (instancetype)initWithAttributedString:(NSAttributedString *)attributedString
{
    self = [super initWithTextContentManager:nil];
    if (self) {
        _attributedString = attributedString;   /* stored as-is (measured: same object) */
    }
    return self;
}

- (instancetype)init { return [self initWithAttributedString:nil]; }

- (NSAttributedString *)attributedString { return _attributedString; }
- (NSTextRange *)paragraphContentRange { return _paragraphContentRange; }
- (void)setParagraphContentRange:(NSTextRange *)r { _paragraphContentRange = r; }
- (NSTextRange *)paragraphSeparatorRange { return _paragraphSeparatorRange; }
- (void)setParagraphSeparatorRange:(NSTextRange *)r { _paragraphSeparatorRange = r; }

@end
