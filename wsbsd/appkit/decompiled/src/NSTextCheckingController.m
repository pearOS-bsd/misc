/*
 * NSTextCheckingController.m — behavioral-1:1 core. See the header.
 */

#import "NSTextCheckingController.h"

@implementation NSTextCheckingController {
    __weak id _client;
    NSInteger _spellCheckerDocumentTag;
}

- (instancetype)initWithClient:(id)client
{
    self = [super init];
    if (self) {
        _client = client;
        /* NSSpellChecker hands out monotonically increasing document tags; the
           first controller in a process observes 1 (measured). */
        static NSInteger gNextTag = 1;
        @synchronized ([NSTextCheckingController class]) {
            _spellCheckerDocumentTag = gNextTag++;
        }
    }
    return self;
}

- (id)client { return _client; }
- (NSInteger)spellCheckerDocumentTag { return _spellCheckerDocumentTag; }
- (void)setSpellCheckerDocumentTag:(NSInteger)t { _spellCheckerDocumentTag = t; }

- (NSArray<NSString *> *)validAnnotations
{
    /* the fixed annotation-key set the controller understands (measured). */
    return @[
        @"NSAccessibilitySpellingState", @"NSCompletionString", @"NSDataDetection",
        @"NSDominantLanguageAttributeName", @"NSDominantScriptAttributeName",
        @"NSEmojiCheckingAttributeName", @"NSGrammarCorrections", @"NSGrammarLeftOffset",
        @"NSGrammarRightOffset", @"NSGrammarUserDescription", @"NSGrammarConfidenceScore",
        @"NSGrammarIssueType", @"NSGrammarTargetPair", @"NSGrammarSystemCategory",
        @"NSGrammarUserCategory", @"NSGrammarUUID", @"NSIgnoringSubstitution",
        @"NSLanguageMapAttributeName", @"NSLink", @"NSOrthography",
        @"NSPostEditingCorrection", @"NSReplacedString", @"NSSpellingState",
        @"NSTemporaryTextCorrection", @"NSTextAlternatives", @"NSTextChecked",
        @"NSTextCompleted", @"NSTextCompletion", @"NSTextCorrection", @"NSTextEdited",
        @"NSTextReplacementAttributeName", @"NSTextReverted",
    ];
}

/* lifecycle hooks — the real checking pipeline is stage2; these keep the
   client contract callable without faulting. */
- (void)didChangeTextInRange:(NSRange)range {}
- (void)didChangeText {}
- (void)didChangeSelectedRange {}
- (void)invalidate {}

@end
