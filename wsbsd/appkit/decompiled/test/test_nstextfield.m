/*
 * test_nstextfield.m — NSTextField delegating to NSTextFieldCell: stringValue,
 * editable/selectable/bezeled/bordered flags, and labelWithString:.
 */
#import "../src/NSTextField.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        NSTextField *tf = [[NSTextField alloc] initWithFrame:CGRectMake(0, 0, 120, 22)];
        CHECK([tf.cell isKindOfClass:[NSTextFieldCell class]], "cell is NSTextFieldCell");

        /* stringValue via cell */
        tf.stringValue = @"hello";
        CHECK([tf.stringValue isEqualToString:@"hello"], "stringValue round-trips via cell");

        /* flags delegate to cell */
        tf.editable = YES;
        CHECK(tf.isEditable, "editable set");
        CHECK(tf.isSelectable, "editable implies selectable");
        tf.editable = NO;
        tf.selectable = YES;
        CHECK(!tf.isEditable && tf.isSelectable, "selectable without editable");

        /* bordered / bezeled are mutually exclusive */
        tf.bezeled = YES;
        CHECK(tf.isBezeled && !tf.isBordered, "bezeled set, bordered cleared");
        tf.bordered = YES;
        CHECK(tf.isBordered && !tf.isBezeled, "bordered set, bezeled cleared");

        /* the flags live on the cell */
        CHECK([tf.cell isBordered], "flag actually stored on the cell");

        /* label convenience */
        NSTextField *label = [NSTextField labelWithString:@"Name:"];
        CHECK([label.stringValue isEqualToString:@"Name:"], "label shows the string");
        CHECK(!label.isEditable && !label.isSelectable, "label not editable/selectable");
        CHECK(!label.isBezeled && !label.isBordered, "label has no bezel or border");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
