/* test_nstextview.m */
#import "../src/NSTextView.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSTextView *v = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,200,100)];
        CHECK([v isKindOfClass:[NSText class]], "is-a NSText");

        /* measured defaults */
        CHECK(!v.allowsUndo, "allowsUndo NO default");
        CHECK(!v.isContinuousSpellCheckingEnabled, "continuousSpellChecking NO default");
        CHECK(v.isGrammarCheckingEnabled, "grammarChecking YES default");
        CHECK(v.isAutomaticQuoteSubstitutionEnabled, "autoQuote YES default");
        CHECK(!v.isAutomaticLinkDetectionEnabled, "autoLink NO default");
        CHECK(v.isAutomaticDashSubstitutionEnabled, "autoDash YES default");
        CHECK(v.isAutomaticTextReplacementEnabled, "autoTextReplacement YES default");
        CHECK(v.smartInsertDeleteEnabled, "smartInsertDelete YES default");
        CHECK(v.usesRuler, "usesRuler YES default");
        CHECK(!v.isRulerVisible, "rulerVisible NO default");
        CHECK(!v.usesFindPanel && !v.usesFindBar && !v.usesInspectorBar, "find/inspector bars NO default");
        CHECK(v.textContainerInset.width == 0 && v.textContainerInset.height == 0, "textContainerInset zero default");
        CHECK(v.textContainer != nil, "textContainer auto-created (non-nil, measured)");

        /* inherits NSText defaults */
        CHECK(v.isEditable && v.isRichText && v.drawsBackground, "inherits NSText editable/rich/drawsBackground");

        /* explicit container init */
        id container = v.textContainer;
        NSTextView *v2 = [[NSTextView alloc] initWithFrame:NSMakeRect(0,0,10,10) textContainer:(id)container];
        CHECK(v2.textContainer == container, "explicit textContainer stored");

        /* setters */
        v.allowsUndo = YES; CHECK(v.allowsUndo, "allowsUndo set");
        v.automaticQuoteSubstitutionEnabled = NO; CHECK(!v.isAutomaticQuoteSubstitutionEnabled, "autoQuote set");
        v.textContainerInset = CGSizeMake(4, 8); CHECK(v.textContainerInset.height == 8, "textContainerInset set");
        v.rulerVisible = YES; CHECK(v.isRulerVisible, "rulerVisible set");

        /* inherited string/selection behaviour still works */
        v.string = @"abc";
        CHECK([v.string isEqual:@"abc"], "inherited setString works");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
