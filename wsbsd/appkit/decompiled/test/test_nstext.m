/* test_nstext.m */
#import "../src/NSText.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSText *t = [[NSText alloc] initWithFrame:NSMakeRect(0,0,200,100)];
        CHECK([t isKindOfClass:[NSView class]], "is-a NSView");

        /* measured defaults */
        CHECK(t.isEditable && t.isSelectable && t.isRichText, "editable/selectable/richText YES default");
        CHECK(!t.isFieldEditor, "fieldEditor NO default");
        CHECK(t.usesFontPanel && t.drawsBackground, "usesFontPanel/drawsBackground YES default");
        CHECK(!t.isHorizontallyResizable && t.isVerticallyResizable, "resizable flags default");
        CHECK(t.alignment == NSTextAlignmentNatural, "alignment Natural default");
        CHECK([t.string isEqual:@""], "empty string default");
        CHECK(t.selectedRange.location == 0 && t.selectedRange.length == 0, "empty selection default");

        /* enum */
        CHECK(NSTextAlignmentLeft == 0 && NSTextAlignmentNatural == 4, "alignment enum (modern)");

        /* string + selection */
        t.string = @"Hello";
        CHECK([t.string isEqual:@"Hello"], "setString");
        t.selectedRange = NSMakeRange(1, 3);
        CHECK(t.selectedRange.location == 1 && t.selectedRange.length == 3, "selectedRange set");
        /* out-of-range selection clamps to string */
        t.selectedRange = NSMakeRange(3, 99);
        CHECK(t.selectedRange.location == 3 && t.selectedRange.length == 2, "selection clamped to string length");

        /* replaceCharactersInRange */
        [t replaceCharactersInRange:NSMakeRange(0, 5) withString:@"Hi"];
        CHECK([t.string isEqual:@"Hi"], "replaceCharactersInRange");
        CHECK(t.selectedRange.location <= 2, "selection re-clamped after replace");
        [t replaceCharactersInRange:NSMakeRange(0, 99) withString:@"x"];
        CHECK([t.string isEqual:@"Hi"], "out-of-range replace ignored");

        /* editable/selectable coupling */
        t.selectable = NO;
        CHECK(!t.isSelectable && !t.isEditable, "clearing selectable clears editable");
        t.editable = YES;
        CHECK(t.isEditable && t.isSelectable, "setting editable restores selectable");

        /* setString clamps selection to new (shorter) content */
        t.selectedRange = NSMakeRange(2, 0);
        t.string = @"";
        CHECK(t.selectedRange.location == 0, "selection clamped when string shrinks");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
