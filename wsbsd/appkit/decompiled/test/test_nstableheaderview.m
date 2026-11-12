/* test_nstableheaderview.m */
#import "../src/NSTableHeaderView.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSTableHeaderView *h = [[NSTableHeaderView alloc] initWithFrame:NSMakeRect(0,0,200,20)];
        CHECK([h isKindOfClass:[NSView class]], "is-a NSView");

        /* measured defaults */
        CHECK(h.tableView == nil, "tableView nil default");
        CHECK(h.draggedColumn == -1, "draggedColumn -1 idle");
        CHECK(h.draggedDistance == 0.0, "draggedDistance 0 idle");
        CHECK(h.resizedColumn == -1, "resizedColumn -1 idle");
        CHECK([h columnAtPoint:NSMakePoint(5,5)] == -1, "columnAtPoint -1 without table");
        CHECK(CGRectEqualToRect([h headerRectOfColumn:0], CGRectZero), "headerRectOfColumn zero without table");

        /* tableView settable (weak) */
        id tv = [NSObject new];
        h.tableView = (id)tv;
        CHECK((id)h.tableView == tv, "tableView set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
