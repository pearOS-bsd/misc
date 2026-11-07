/* test_nstableview.m — NSTableView column management + geometry/flags. */
#import "../src/NSTableView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTableView *tv = [[NSTableView alloc] initWithFrame:CGRectMake(0, 0, 400, 300)];
        CHECK(tv.numberOfColumns == 0, "no columns to start");
        CHECK(tv.rowHeight == 17.0, "default rowHeight");
        CHECK(tv.allowsColumnReordering == YES, "allowsColumnReordering defaults YES");

        NSTableColumn *name = [[NSTableColumn alloc] initWithIdentifier:@"name"];
        NSTableColumn *size = [[NSTableColumn alloc] initWithIdentifier:@"size"];
        [tv addTableColumn:name];
        [tv addTableColumn:size];
        CHECK(tv.numberOfColumns == 2, "two columns");
        CHECK(tv.tableColumns[0] == name && tv.tableColumns[1] == size, "columns in order");
        CHECK([tv columnWithIdentifier:@"size"] == size, "columnWithIdentifier finds it");
        CHECK([tv columnIndexWithIdentifier:@"size"] == 1, "columnIndexWithIdentifier");
        CHECK([tv columnWithIdentifier:@"nope"] == nil, "missing identifier -> nil");

        /* rowHeight rejects <= 0 */
        tv.rowHeight = 24.0;
        CHECK(tv.rowHeight == 24.0, "rowHeight round-trips");
        tv.rowHeight = -5.0;
        CHECK(tv.rowHeight == 24.0, "rowHeight rejects non-positive");

        tv.allowsColumnReordering = NO;
        CHECK(!tv.allowsColumnReordering, "allowsColumnReordering round-trips");

        [tv removeTableColumn:name];
        CHECK(tv.numberOfColumns == 1 && [tv columnWithIdentifier:@"name"] == nil, "removeTableColumn");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
