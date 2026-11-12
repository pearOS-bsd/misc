/*
 * NSTextLayoutManager.m — behavioral-1:1 core. See the header.
 */

#import "NSTextLayoutManager.h"
#import "NSTextContentManager.h"

@implementation NSTextLayoutManager {
    __weak id<NSTextLayoutManagerDelegate> _delegate;
    __weak NSTextContentManager *_textContentManager;
    NSTextContainer *_textContainer;
    BOOL _usesFontLeading;
    BOOL _limitsLayoutForSuspiciousContents;
    BOOL _usesHyphenation;
    NSArray *_textSelections;
    NSTextSelectionNavigation *_textSelectionNavigation;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _usesFontLeading = YES;   /* measured */
        /* usesHyphenation NO, limits NO, textSelections nil (measured) */
    }
    return self;
}

- (id<NSTextLayoutManagerDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<NSTextLayoutManagerDelegate>)d { _delegate = d; }
- (NSTextContentManager *)textContentManager { return _textContentManager; }
- (void)setTextContentManager:(NSTextContentManager *)m { _textContentManager = m; }
- (NSTextContainer *)textContainer { return _textContainer; }
- (void)setTextContainer:(NSTextContainer *)c { _textContainer = c; }
- (BOOL)usesFontLeading { return _usesFontLeading; }
- (void)setUsesFontLeading:(BOOL)v { _usesFontLeading = v; }
- (BOOL)limitsLayoutForSuspiciousContents { return _limitsLayoutForSuspiciousContents; }
- (void)setLimitsLayoutForSuspiciousContents:(BOOL)v { _limitsLayoutForSuspiciousContents = v; }
- (BOOL)usesHyphenation { return _usesHyphenation; }
- (void)setUsesHyphenation:(BOOL)v { _usesHyphenation = v; }
- (NSArray *)textSelections { return _textSelections; }
- (void)setTextSelections:(NSArray *)s { _textSelections = [s copy]; }

- (NSTextRange *)documentRange { return [_textContentManager documentRange]; }

- (CGRect)usageBoundsForTextContainer { return CGRectZero; }   /* layout = stage2 */

- (NSTextSelectionNavigation *)textSelectionNavigation
{
    if (!_textSelectionNavigation) {
        /* lazily created in the real class; our NSTextSelectionNavigation core
           may not be linked, so create it only when available. */
        Class cls = NSClassFromString(@"NSTextSelectionNavigation");
        if (cls) _textSelectionNavigation = [[cls alloc] init];
    }
    return _textSelectionNavigation;
}

@end
