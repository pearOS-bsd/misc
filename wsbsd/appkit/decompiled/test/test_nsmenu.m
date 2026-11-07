/*
 * test_nsmenu.m — NSMenu core: title, item array, insert/add/remove, lookups.
 */
#import "../src/NSMenu.h"
#import "../src/NSMenuItem.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        NSMenu *m = [[NSMenu alloc] initWithTitle:@"File"];
        CHECK([m.title isEqualToString:@"File"], "init sets title");
        CHECK(m.numberOfItems == 0, "new menu is empty");
        CHECK(m.itemArray.count == 0, "empty item array");

        NSMenuItem *open = [[NSMenuItem alloc] initWithTitle:@"Open" action:NULL keyEquivalent:@"o"];
        NSMenuItem *save = [[NSMenuItem alloc] initWithTitle:@"Save" action:NULL keyEquivalent:@"s"];
        [m addItem:open];
        [m addItem:save];
        CHECK(m.numberOfItems == 2, "two items added");
        CHECK([m itemAtIndex:0] == open && [m itemAtIndex:1] == save, "items in order");

        /* itemArray is a copy */
        NSArray *a1 = m.itemArray, *a2 = m.itemArray;
        CHECK(a1 != a2, "itemArray returns a copy");

        /* insert at index */
        NSMenuItem *neu = [[NSMenuItem alloc] initWithTitle:@"New" action:NULL keyEquivalent:@"n"];
        [m insertItem:neu atIndex:0];
        CHECK([m itemAtIndex:0] == neu && m.numberOfItems == 3, "insertItem:atIndex: at front");

        /* indexOfItem */
        CHECK([m indexOfItem:save] == 2, "indexOfItem finds the item");
        NSMenuItem *stray = [[NSMenuItem alloc] initWithTitle:@"X" action:NULL keyEquivalent:@""];
        CHECK([m indexOfItem:stray] == -1, "indexOfItem returns -1 when absent");

        /* lookups */
        CHECK([m itemWithTitle:@"Open"] == open, "itemWithTitle finds item");
        save.tag = 77;
        CHECK([m itemWithTag:77] == save, "itemWithTag finds item");
        CHECK([m itemWithTitle:@"Nope"] == nil, "itemWithTitle nil when absent");

        /* remove */
        [m removeItem:open];
        CHECK(m.numberOfItems == 2 && [m indexOfItem:open] == -1, "removeItem drops the item");
        [m removeItemAtIndex:0];
        CHECK(m.numberOfItems == 1, "removeItemAtIndex drops by index");

        /* convenience add */
        NSMenuItem *q = [m addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
        CHECK([q.title isEqualToString:@"Quit"] && [m indexOfItem:q] >= 0,
              "addItemWithTitle builds and appends an item");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
