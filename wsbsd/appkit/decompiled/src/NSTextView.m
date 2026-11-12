/*
 * NSTextView.m — behavioral-1:1 core. See the header.
 */

#import "NSTextView.h"
#import "NSTextContainer.h"

@implementation NSTextView {
    NSTextContainer *_textContainer;
    CGSize _textContainerInset;
    BOOL _allowsUndo;
    BOOL _continuousSpellCheckingEnabled;
    BOOL _grammarCheckingEnabled;
    BOOL _automaticQuoteSubstitutionEnabled;
    BOOL _automaticLinkDetectionEnabled;
    BOOL _automaticDashSubstitutionEnabled;
    BOOL _automaticTextReplacementEnabled;
    BOOL _smartInsertDeleteEnabled;
    BOOL _usesRuler;
    BOOL _usesFindPanel;
    BOOL _usesFindBar;
    BOOL _usesInspectorBar;
    BOOL _rulerVisible;
    NSColor *_insertionPointColor;
}

- (instancetype)initWithFrame:(CGRect)frameRect { return [self initWithFrame:frameRect textContainer:nil]; }

- (instancetype)initWithFrame:(CGRect)frameRect textContainer:(NSTextContainer *)container
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _textContainer = container ?: [[NSTextContainer alloc] initWithSize:CGSizeMake(frameRect.size.width, 1e7)];
        /* measured defaults */
        _grammarCheckingEnabled = YES;
        _automaticQuoteSubstitutionEnabled = YES;
        _automaticDashSubstitutionEnabled = YES;
        _automaticTextReplacementEnabled = YES;
        _smartInsertDeleteEnabled = YES;
        _usesRuler = YES;
        /* allowsUndo/continuousSpellChecking/autoLink/rulerVisible/usesFindPanel/
           usesFindBar/usesInspectorBar = NO; textContainerInset = {0,0} (measured). */
    }
    return self;
}

- (NSTextContainer *)textContainer { return _textContainer; }
- (void)setTextContainer:(NSTextContainer *)c { _textContainer = c; }
- (CGSize)textContainerInset { return _textContainerInset; }
- (void)setTextContainerInset:(CGSize)s { _textContainerInset = s; }
- (BOOL)allowsUndo { return _allowsUndo; }
- (void)setAllowsUndo:(BOOL)v { _allowsUndo = v; }
- (BOOL)isContinuousSpellCheckingEnabled { return _continuousSpellCheckingEnabled; }
- (void)setContinuousSpellCheckingEnabled:(BOOL)v { _continuousSpellCheckingEnabled = v; }
- (BOOL)isGrammarCheckingEnabled { return _grammarCheckingEnabled; }
- (void)setGrammarCheckingEnabled:(BOOL)v { _grammarCheckingEnabled = v; }
- (BOOL)isAutomaticQuoteSubstitutionEnabled { return _automaticQuoteSubstitutionEnabled; }
- (void)setAutomaticQuoteSubstitutionEnabled:(BOOL)v { _automaticQuoteSubstitutionEnabled = v; }
- (BOOL)isAutomaticLinkDetectionEnabled { return _automaticLinkDetectionEnabled; }
- (void)setAutomaticLinkDetectionEnabled:(BOOL)v { _automaticLinkDetectionEnabled = v; }
- (BOOL)isAutomaticDashSubstitutionEnabled { return _automaticDashSubstitutionEnabled; }
- (void)setAutomaticDashSubstitutionEnabled:(BOOL)v { _automaticDashSubstitutionEnabled = v; }
- (BOOL)isAutomaticTextReplacementEnabled { return _automaticTextReplacementEnabled; }
- (void)setAutomaticTextReplacementEnabled:(BOOL)v { _automaticTextReplacementEnabled = v; }
- (BOOL)smartInsertDeleteEnabled { return _smartInsertDeleteEnabled; }
- (void)setSmartInsertDeleteEnabled:(BOOL)v { _smartInsertDeleteEnabled = v; }
- (BOOL)usesRuler { return _usesRuler; }
- (void)setUsesRuler:(BOOL)v { _usesRuler = v; }
- (BOOL)usesFindPanel { return _usesFindPanel; }
- (void)setUsesFindPanel:(BOOL)v { _usesFindPanel = v; }
- (BOOL)usesFindBar { return _usesFindBar; }
- (void)setUsesFindBar:(BOOL)v { _usesFindBar = v; }
- (BOOL)usesInspectorBar { return _usesInspectorBar; }
- (void)setUsesInspectorBar:(BOOL)v { _usesInspectorBar = v; }
- (BOOL)isRulerVisible { return _rulerVisible; }
- (void)setRulerVisible:(BOOL)v { _rulerVisible = v; }
- (NSColor *)insertionPointColor { return _insertionPointColor; }
- (void)setInsertionPointColor:(NSColor *)c { _insertionPointColor = c; }

@end
