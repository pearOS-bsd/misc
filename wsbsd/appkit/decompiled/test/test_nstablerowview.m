/* test_nstablerowview.m */
#import "../src/NSTableRowView.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSTableRowView *r = [[NSTableRowView alloc] initWithFrame:NSMakeRect(0,0,200,20)];
        CHECK([r isKindOfClass:[NSView class]], "is-a NSView");

        /* measured defaults */
        CHECK(!r.isSelected, "not selected default");
        CHECK(r.selectionHighlightStyle == NSTableViewSelectionHighlightStyleRegular, "selectionHighlightStyle Regular default");
        CHECK(!r.isEmphasized, "not emphasized default");
        CHECK(!r.isFloating, "not floating default");
        CHECK(!r.isGroupRowStyle, "not group row default");
        CHECK(r.numberOfColumns == 0, "no columns default");
        CHECK(!r.targetForDropOperation, "targetForDropOperation NO default");
        CHECK(r.draggingDestinationFeedbackStyle == 0, "dragging feedback 0 default");
        CHECK(r.interiorBackgroundStyle == NSBackgroundStyleNormal, "interiorBackgroundStyle Normal default");

        /* enums */
        CHECK(NSTableViewSelectionHighlightStyleNone == -1 && NSTableViewSelectionHighlightStyleSourceList == 1, "selection style enum");
        CHECK(NSBackgroundStyleNormal == 0 && NSBackgroundStyleEmphasized == 1, "background style enum");

        /* interiorBackgroundStyle derives from selected+emphasized */
        r.selected = YES;
        CHECK(r.interiorBackgroundStyle == NSBackgroundStyleNormal, "selected-but-not-emphasized stays Normal");
        r.emphasized = YES;
        CHECK(r.interiorBackgroundStyle == NSBackgroundStyleEmphasized, "selected+emphasized -> Emphasized");
        r.selected = NO;
        CHECK(r.interiorBackgroundStyle == NSBackgroundStyleNormal, "deselected -> Normal");

        /* setters */
        r.groupRowStyle = YES; CHECK(r.isGroupRowStyle, "groupRowStyle set");
        r.selectionHighlightStyle = NSTableViewSelectionHighlightStyleSourceList;
        CHECK(r.selectionHighlightStyle == NSTableViewSelectionHighlightStyleSourceList, "selectionHighlightStyle set");
        r.targetForDropOperation = YES; CHECK(r.targetForDropOperation, "targetForDropOperation set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
