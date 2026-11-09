/* test_nstexttableblock.m — NSTextTableBlock (: NSTextBlock). */
#import "../src/NSTextTableBlock.h"
#import "../src/NSTextTable.h"
#import "../src/NSTextBlock.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTextTable *table = [[NSTextTable alloc] init];
        table.numberOfColumns = 3;
        NSTextTableBlock *cell = [[NSTextTableBlock alloc] initWithTable:table
                                                            startingRow:1 rowSpan:2
                                                         startingColumn:0 columnSpan:1];
        CHECK([cell isKindOfClass:[NSTextBlock class]], "NSTextTableBlock is an NSTextBlock");
        CHECK(cell.table == table, "owning table stored");
        CHECK(cell.startingRow == 1 && cell.rowSpan == 2, "row placement stored");
        CHECK(cell.startingColumn == 0 && cell.columnSpan == 1, "column placement stored");

        /* inherited block state works */
        [cell setContentWidth:120 type:NSTextBlockAbsoluteValueType];
        CHECK(cell.contentWidth == 120, "inherited contentWidth works");

        /* copy is an NSTextTableBlock carrying both layers */
        NSTextTableBlock *c = [cell copy];
        CHECK([c isKindOfClass:[NSTextTableBlock class]], "copy is an NSTextTableBlock");
        CHECK(c.table == table && c.startingRow == 1 && c.columnSpan == 1, "copy carries table coords");
        CHECK(c.contentWidth == 120, "copy carries inherited block state");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
