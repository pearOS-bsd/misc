/* test_nsformcell.m — behaviour checks for NSFormCell core */
#import "../src/NSFormCell.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSFormCell *c = [[NSFormCell alloc] initTextCell:@"Name:"];
        CHECK([c isKindOfClass:[NSActionCell class]], "is an NSActionCell");

        /* title from initTextCell + measured defaults */
        CHECK([c.title isEqual:@"Name:"], "title from initTextCell");
        CHECK(c.titleAlignment == NSTextAlignmentRight, "titleAlignment default Right(2)");
        CHECK(c.titleBaseWritingDirection == NSWritingDirectionNatural, "titleBaseWritingDirection default Natural(-1)");
        CHECK(c.preferredTextFieldWidth == -1, "preferredTextFieldWidth default -1");
        CHECK(c.titleWidth == -1, "titleWidth default -1 (auto sentinel)");
        CHECK(c.placeholderString == nil, "placeholder nil");

        /* enum values (modern ordering) */
        CHECK(NSTextAlignmentLeft == 0 && NSTextAlignmentCenter == 1 && NSTextAlignmentRight == 2, "modern NSTextAlignment ordering");

        /* setters */
        c.title = @"Email:";
        CHECK([c.title isEqual:@"Email:"], "title set");
        c.titleWidth = 80;
        CHECK(c.titleWidth == 80, "titleWidth explicit set");
        c.titleAlignment = NSTextAlignmentLeft;
        CHECK(c.titleAlignment == NSTextAlignmentLeft, "titleAlignment set");
        c.preferredTextFieldWidth = 120;
        CHECK(c.preferredTextFieldWidth == 120, "preferredTextFieldWidth set");

        /* placeholder string/attributed are mutually exclusive */
        c.placeholderString = @"you@example.com";
        CHECK([c.placeholderString isEqual:@"you@example.com"], "placeholderString set");

        /* copy carries the value model */
        NSFormCell *cp = [c copy];
        CHECK([cp isKindOfClass:[NSFormCell class]], "copy is an NSFormCell");
        CHECK([cp.title isEqual:@"Email:"] && cp.titleWidth == 80
              && cp.titleAlignment == NSTextAlignmentLeft && cp.preferredTextFieldWidth == 120
              && [cp.placeholderString isEqual:@"you@example.com"], "copy carries value model");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
