/* test_nsarraycontroller.m — behaviour checks for NSArrayController core */
#import "../src/NSArrayController.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSArrayController *a = [[NSArrayController alloc] init];
        CHECK([a isKindOfClass:[NSObjectController class]], "is an NSObjectController");

        /* measured defaults */
        CHECK(a.isEditable, "editable YES");
        CHECK(a.avoidsEmptySelection && a.preservesSelection && a.selectsInsertedObjects, "selection flags default YES");
        CHECK(!a.alwaysUsesMultipleValuesMarker && !a.automaticallyRearrangesObjects, "marker/autoRearrange default NO");
        CHECK(a.clearsFilterPredicateOnInsertion, "clearsFilterPredicateOnInsertion YES");
        CHECK([a.content isKindOfClass:[NSArray class]] && [a.content count] == 0, "content empty array");
        CHECK([a.arrangedObjects count] == 0, "arranged empty");
        CHECK(a.selectionIndex == NSNotFound, "no selection initially");
        CHECK(a.canInsert && !a.canRemove, "canInsert YES, canRemove NO empty");

        /* sort: arrangeObjects sorts ascending */
        a.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"self" ascending:YES]];
        [a addObjects:@[@3, @1, @2]];
        NSArray *arr = a.arrangedObjects;
        CHECK(arr.count == 3 && [arr[0] isEqual:@1] && [arr[2] isEqual:@3], "arranged sorted ascending");
        /* selectsInserted + avoidsEmpty: all inserted selected, selectionIndex 0 */
        CHECK(a.selectedObjects.count == 3 && a.selectionIndex == 0, "inserted objects selected, index 0 first");

        /* filterPredicate narrows arrangedObjects */
        a.filterPredicate = [NSPredicate predicateWithFormat:@"self > 1"];
        CHECK([a.arrangedObjects count] == 2 && [[a arrangedObjects][0] isEqual:@2], "filter narrows arranged");

        /* setContent + avoidsEmptySelection picks index 0 */
        NSArrayController *b = [[NSArrayController alloc] init];
        b.content = @[@"a", @"b", @"c"];
        CHECK([b.arrangedObjects count] == 3 && b.selectionIndex == 0, "setContent selects index 0");

        /* explicit selection + navigation */
        [b setSelectionIndex:0];
        CHECK(b.canSelectNext && !b.canSelectPrevious, "at first: canNext yes, canPrev no");
        [b selectNext:nil];
        CHECK(b.selectionIndex == 1, "selectNext advances");
        [b selectPrevious:nil];
        CHECK(b.selectionIndex == 0, "selectPrevious goes back");
        [b setSelectionIndex:2];
        CHECK(!b.canSelectNext && b.canSelectPrevious, "at last: canNext no");

        /* multi-selection add/remove */
        [b setSelectionIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,2)]];
        CHECK(b.selectedObjects.count == 2, "set two selected");
        [b removeSelectionIndexes:[NSIndexSet indexSetWithIndex:0]];
        CHECK(b.selectedObjects.count == 1 && [b.selectedObjects[0] isEqual:@"b"], "removed one from selection");

        /* removing selected object + avoidsEmptySelection keeps a selection */
        NSArrayController *c = [[NSArrayController alloc] init];
        c.content = @[@"x", @"y"];
        [c setSelectionIndex:1];
        [c removeObjects:@[@"y"]];
        CHECK([c.arrangedObjects count] == 1 && c.selectionIndex == 0, "avoidsEmptySelection reselects after removal");

        /* out-of-range selection is pruned */
        NSArrayController *d = [[NSArrayController alloc] init];
        d.content = @[@1, @2, @3];
        [d setSelectionIndexes:[NSIndexSet indexSetWithIndex:99]];
        CHECK(d.selectionIndex == 0, "out-of-range selection pruned then avoidsEmpty picks 0");

        /* remove: action clears selected objects */
        NSArrayController *e = [[NSArrayController alloc] init];
        e.content = @[@"k", @"l", @"m"];
        [e setSelectionIndex:1];
        NSUInteger before = [e.arrangedObjects count];
        [e remove:nil];
        CHECK([e.arrangedObjects count] == before - 1, "remove: drops the selected object");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
