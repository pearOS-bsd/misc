/* test_nstreenode.m — NSTreeNode tree model + parentNode/indexPath. */
#import "../src/NSTreeNode.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSTreeNode *root = [NSTreeNode treeNodeWithRepresentedObject:@"root"];
        CHECK([root.representedObject isEqualToString:@"root"], "representedObject stored");
        CHECK(root.isLeaf, "fresh node is a leaf");
        CHECK(root.parentNode == nil, "root has no parent");
        CHECK(root.childNodes.count == 0, "no children initially");

        NSTreeNode *a = [NSTreeNode treeNodeWithRepresentedObject:@"a"];
        NSTreeNode *b = [NSTreeNode treeNodeWithRepresentedObject:@"b"];
        [root.mutableChildNodes addObject:a];
        [root.mutableChildNodes addObject:b];
        CHECK(root.childNodes.count == 2, "two children added");
        CHECK(!root.isLeaf, "node with children is not a leaf");
        CHECK(a.parentNode == root, "adding a child sets its parentNode");
        CHECK(b.parentNode == root, "second child parent set");

        /* grandchild */
        NSTreeNode *a0 = [NSTreeNode treeNodeWithRepresentedObject:@"a0"];
        [a.mutableChildNodes addObject:a0];
        CHECK(a0.parentNode == a, "grandchild parent is a");

        /* indexPath walks up: a0 is root.children[0].children[0] -> [0,0] */
        NSIndexPath *ip = a0.indexPath;
        CHECK(ip.length == 2, "grandchild index path length 2");
        CHECK([ip indexAtPosition:0] == 0 && [ip indexAtPosition:1] == 0, "a0 index path [0,0]");

        /* b is root.children[1] -> [1] */
        NSIndexPath *ipb = b.indexPath;
        CHECK(ipb.length == 1 && [ipb indexAtPosition:0] == 1, "b index path [1]");

        /* descendantNodeAtIndexPath round-trips */
        CHECK([root descendantNodeAtIndexPath:ip] == a0, "descendant at [0,0] is a0");
        CHECK([root descendantNodeAtIndexPath:ipb] == b, "descendant at [1] is b");
        NSIndexPath *bad = [[NSIndexPath indexPathWithIndex:9] indexPathByAddingIndex:9];
        CHECK([root descendantNodeAtIndexPath:bad] == nil, "out-of-range index path -> nil");

        /* insert at index maintains parent + order */
        NSTreeNode *mid = [NSTreeNode treeNodeWithRepresentedObject:@"mid"];
        [root.mutableChildNodes insertObject:mid atIndex:1];
        CHECK(root.childNodes.count == 3, "insert grows children");
        CHECK(mid.parentNode == root, "inserted child parent set");
        CHECK([mid.indexPath indexAtPosition:0] == 1, "inserted child at index 1");
        CHECK([b.indexPath indexAtPosition:0] == 2, "b shifted to index 2");

        /* removal clears parent */
        [root.mutableChildNodes removeObjectAtIndex:0]; /* removes a */
        CHECK(a.parentNode == nil, "removed child parent cleared");
        CHECK(root.childNodes.count == 2, "remove shrinks children");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
