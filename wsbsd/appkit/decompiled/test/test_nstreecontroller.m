/* test_nstreecontroller.m — behaviour checks for NSTreeController core */
#import "../src/NSTreeController.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

static NSMutableDictionary *Node(NSString *name, NSArray *kids) {
    return [@{ @"name": name, @"kids": [kids mutableCopy] } mutableCopy];
}

int main(void) {
    @autoreleasepool {
        NSTreeController *t = [[NSTreeController alloc] init];
        CHECK([t isKindOfClass:[NSObjectController class]], "is an NSObjectController");

        /* measured defaults */
        CHECK(t.isEditable, "editable YES");
        CHECK(t.avoidsEmptySelection && t.preservesSelection && t.selectsInsertedObjects, "selection flags YES");
        CHECK(!t.alwaysUsesMultipleValuesMarker, "alwaysUsesMultipleValuesMarker NO");
        CHECK(t.childrenKeyPath == nil && t.countKeyPath == nil && t.leafKeyPath == nil, "key paths nil");

        /* arrangedObjects raises when childrenKeyPath is nil */
        BOOL raised = NO;
        @try { (void)t.arrangedObjects; } @catch (NSException *e) { raised = [e.name isEqual:NSInternalInconsistencyException]; }
        CHECK(raised, "arrangedObjects raises when childrenKeyPath nil");

        /* build a tree from content via childrenKeyPath */
        t.childrenKeyPath = @"kids";
        NSMutableDictionary *leaf = Node(@"leaf", @[]);
        NSMutableDictionary *root = Node(@"root", @[leaf]);
        t.content = @[root];
        NSTreeNode *arranged = t.arrangedObjects;
        CHECK(arranged != nil && arranged.childNodes.count == 1, "one top-level node");
        NSTreeNode *n0 = arranged.childNodes[0];
        CHECK([[n0.representedObject valueForKey:@"name"] isEqual:@"root"], "top node represents root");
        CHECK(n0.indexPath.length == 1 && [n0.indexPath indexAtPosition:0] == 0, "top node indexPath {0}");
        CHECK(n0.childNodes.count == 1, "root has one child node");
        CHECK([[n0.childNodes[0].representedObject valueForKey:@"name"] isEqual:@"leaf"], "grandchild is leaf");

        /* avoidsEmptySelection selected {0}; selectedObjects follows */
        CHECK(t.selectionIndexPaths.count == 1 && t.selectionIndexPath.length == 1, "avoidsEmptySelection selected first");
        CHECK(t.selectedObjects.count == 1 && t.selectedObjects[0] == root, "selectedObjects is [root]");
        CHECK(t.selectedNodes.count == 1 && t.selectedNodes[0] == n0, "selectedNodes resolves");

        /* single (non-array) content is wrapped */
        NSTreeController *t2 = [[NSTreeController alloc] init];
        t2.childrenKeyPath = @"kids";
        t2.content = Node(@"solo", @[]);
        CHECK(t2.arrangedObjects.childNodes.count == 1, "single content wrapped as one root child");

        /* sortDescriptors order the children */
        NSTreeController *t3 = [[NSTreeController alloc] init];
        t3.childrenKeyPath = @"kids";
        t3.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
        t3.content = @[Node(@"c", @[]), Node(@"a", @[]), Node(@"b", @[])];
        NSArray<NSTreeNode *> *tops = t3.arrangedObjects.childNodes;
        CHECK([[((NSTreeNode *)tops[0]).representedObject valueForKey:@"name"] isEqual:@"a"]
              && [[((NSTreeNode *)tops[2]).representedObject valueForKey:@"name"] isEqual:@"c"], "children sorted by descriptor");

        /* addChild inserts under the selected node */
        NSTreeController *t4 = [[NSTreeController alloc] init];
        t4.childrenKeyPath = @"kids";
        NSMutableDictionary *r = Node(@"r", @[]);
        t4.content = @[r];
        [t4 setSelectionIndexPath:[NSIndexPath indexPathWithIndex:0]];
        [t4 addChild:nil];
        CHECK(t4.arrangedObjects.childNodes[0].childNodes.count == 1, "addChild adds a child node under selection");
        CHECK([(r[@"kids"]) count] == 1, "addChild mutated the model childrenKeyPath");

        /* insert at top level */
        NSTreeController *t5 = [[NSTreeController alloc] init];
        t5.childrenKeyPath = @"kids";
        t5.content = @[Node(@"x", @[])];
        [t5 insertObject:Node(@"y", @[]) atArrangedObjectIndexPath:[NSIndexPath indexPathWithIndex:1]];
        CHECK(t5.arrangedObjects.childNodes.count == 2, "insert at top-level index path");

        /* remove at index path drops the node */
        NSTreeController *t6 = [[NSTreeController alloc] init];
        t6.childrenKeyPath = @"kids";
        t6.content = @[Node(@"a", @[]), Node(@"b", @[])];
        [t6 removeObjectAtArrangedObjectIndexPath:[NSIndexPath indexPathWithIndex:0]];
        CHECK(t6.arrangedObjects.childNodes.count == 1, "remove at index path drops node");

        /* non-editable blocks structural actions */
        NSTreeController *t7 = [[NSTreeController alloc] init];
        t7.childrenKeyPath = @"kids";
        t7.content = @[Node(@"a", @[])];
        t7.editable = NO;
        CHECK(!t7.canInsert && !t7.canAddChild && !t7.canRemove, "non-editable blocks insert/addChild/remove");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
