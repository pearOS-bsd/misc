/* test_nstexttable.m — NSTextTable (: NSTextBlock). */
#import "../src/NSTextTable.h"
#import "../src/NSTextBlock.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTextTable *t = [[NSTextTable alloc] init];
        CHECK([t isKindOfClass:[NSTextBlock class]], "NSTextTable is an NSTextBlock");
        CHECK(t.numberOfColumns == 0, "no columns by default");
        CHECK(t.layoutAlgorithm == NSTextTableAutomaticLayoutAlgorithm, "automatic layout by default");
        CHECK(!t.collapsesBorders && !t.hidesEmptyCells, "flags off by default");

        t.numberOfColumns = 3;
        t.layoutAlgorithm = NSTextTableFixedLayoutAlgorithm;
        t.collapsesBorders = YES;
        t.hidesEmptyCells = YES;
        CHECK(t.numberOfColumns == 3, "columns set");
        CHECK(t.layoutAlgorithm == NSTextTableFixedLayoutAlgorithm, "fixed layout set");
        CHECK(t.collapsesBorders && t.hidesEmptyCells, "flags set");

        /* inherited NSTextBlock behaviour still works */
        [t setContentWidth:400 type:NSTextBlockAbsoluteValueType];
        CHECK(t.contentWidth == 400, "inherited NSTextBlock contentWidth works");

        /* copy returns an NSTextTable (polymorphic) carrying both layers of state */
        NSTextTable *c = [t copy];
        CHECK([c isKindOfClass:[NSTextTable class]], "copy is an NSTextTable");
        CHECK(c.numberOfColumns == 3 && c.collapsesBorders, "copy carries table state");
        CHECK(c.contentWidth == 400, "copy carries inherited block state");
        c.numberOfColumns = 5;
        CHECK(t.numberOfColumns == 3, "copy independent");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
