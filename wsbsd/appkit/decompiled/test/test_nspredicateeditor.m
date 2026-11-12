/* test_nspredicateeditor.m */
#import "../src/NSPredicateEditor.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSPredicateEditor *p = [[NSPredicateEditor alloc] initWithFrame:NSMakeRect(0,0,300,200)];
        CHECK([p isKindOfClass:[NSRuleEditor class]], "is-a NSRuleEditor");

        /* measured: default one compound template */
        CHECK(p.rowTemplates.count == 1, "one default compound row template (measured)");
        CHECK([p.rowTemplates[0] isKindOfClass:[NSPredicateEditorRowTemplate class]], "default template is a row template");

        /* inherits NSRuleEditor config */
        CHECK(p.nestingMode == NSRuleEditorNestingModeCompound, "inherits Compound nesting");
        CHECK(p.rowHeight == 32.0, "inherits rowHeight 32");

        /* rowTemplates settable */
        NSPredicateEditorRowTemplate *t = [[NSPredicateEditorRowTemplate alloc] initWithCompoundTypes:@[@1, @2]];
        p.rowTemplates = @[t, t];
        CHECK(p.rowTemplates.count == 2, "rowTemplates set");

        /* inherited row model still works */
        [p addRow:nil];
        CHECK(p.numberOfRows == 1, "inherited addRow works");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
