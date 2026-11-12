/* test_nsruleeditor.m */
#import "../src/NSRuleEditor.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSRuleEditor *r = [[NSRuleEditor alloc] initWithFrame:NSMakeRect(0,0,300,200)];
        CHECK([r isKindOfClass:[NSControl class]], "is-a NSControl");

        /* measured defaults */
        CHECK(r.nestingMode == NSRuleEditorNestingModeCompound, "nestingMode Compound default");
        CHECK(r.rowHeight == 32.0, "rowHeight 32 default");
        CHECK(r.isEditable, "editable YES default");
        CHECK(r.canRemoveAllRows, "canRemoveAllRows YES default");
        CHECK(r.numberOfRows == 0, "no rows default");
        CHECK([r.rowTypeKeyPath isEqual:@"rowType"], "rowTypeKeyPath default");
        CHECK([r.criteriaKeyPath isEqual:@"criteria"], "criteriaKeyPath default");
        CHECK([r.displayValuesKeyPath isEqual:@"displayValues"], "displayValuesKeyPath default");
        CHECK(r.rowClass == [NSMutableDictionary class], "rowClass NSMutableDictionary default");

        /* enum */
        CHECK(NSRuleEditorNestingModeSingle == 0 && NSRuleEditorNestingModeSimple == 3, "nesting enum");

        /* row model */
        [r addRow:nil];
        CHECK(r.numberOfRows == 1 && [r rowTypeForRow:0] == NSRuleEditorRowTypeSimple, "addRow adds a simple top-level row");
        [r insertRowAtIndex:1 withType:NSRuleEditorRowTypeCompound asSubrowOfRow:0 animate:NO];
        CHECK(r.numberOfRows == 2 && [r rowTypeForRow:1] == NSRuleEditorRowTypeCompound, "insert compound subrow");
        CHECK([r parentRowForRow:1] == 0, "subrow parent recorded");
        [r removeRowAtIndex:0];
        CHECK(r.numberOfRows == 1, "removeRowAtIndex");

        /* setters */
        r.nestingMode = NSRuleEditorNestingModeList; CHECK(r.nestingMode == NSRuleEditorNestingModeList, "nestingMode set");
        r.rowHeight = 40; CHECK(r.rowHeight == 40, "rowHeight set");
        r.editable = NO; CHECK(!r.isEditable, "editable set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
