/* test_nstoolbaritemgroup.m — NSToolbarItemGroup selection models. */
#import "../src/NSToolbarItemGroup.h"
#import "../src/NSToolbarItem.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

static NSToolbarItem *mk(NSString *ident) { return [[NSToolbarItem alloc] initWithItemIdentifier:ident]; }

int main(void)
{
    @autoreleasepool {
        NSToolbarItemGroup *g = [[NSToolbarItemGroup alloc] initWithItemIdentifier:@"group"];
        CHECK([g isKindOfClass:[NSToolbarItem class]], "is an NSToolbarItem");
        CHECK([g.itemIdentifier isEqualToString:@"group"], "identifier inherited");
        CHECK(g.selectionMode == NSToolbarItemGroupSelectionModeSelectOne, "default SelectOne");
        CHECK(g.selectedIndex == -1, "nothing selected initially");

        g.subitems = @[ mk(@"a"), mk(@"b"), mk(@"c") ];
        CHECK(g.subitems.count == 3, "three subitems");

        /* SelectOne: one at a time */
        g.selectedIndex = 1;
        CHECK(g.selectedIndex == 1, "selectedIndex set");
        CHECK([g isSelectedAtIndex:1] && ![g isSelectedAtIndex:0], "only index 1 selected");
        [g setSelected:YES atIndex:2];
        CHECK(g.selectedIndex == 2, "SelectOne moves selection to 2");
        CHECK(![g isSelectedAtIndex:1], "previous selection cleared in SelectOne");

        /* out of range ignored */
        g.selectedIndex = 9;
        CHECK(g.selectedIndex == -1, "out-of-range selectedIndex clears selection");

        /* SelectAny: multiple */
        g.selectionMode = NSToolbarItemGroupSelectionModeSelectAny;
        [g setSelected:YES atIndex:0];
        [g setSelected:YES atIndex:2];
        CHECK([g isSelectedAtIndex:0] && [g isSelectedAtIndex:2], "two selected in SelectAny");
        CHECK(g.selectedIndex == 0, "selectedIndex returns first selected");
        [g setSelected:NO atIndex:0];
        CHECK(![g isSelectedAtIndex:0] && [g isSelectedAtIndex:2], "deselect one keeps the other");

        /* Momentary: no persistent selection */
        g.selectionMode = NSToolbarItemGroupSelectionModeMomentary;
        CHECK(g.selectedIndex == -1, "switching to Momentary clears selection");
        [g setSelected:YES atIndex:1];
        CHECK(g.selectedIndex == -1, "Momentary ignores selection");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
