/* test — NSCollectionViewUpdateItem action inference. */
#import "../src/NSCollectionViewUpdateItem.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

static NSIndexPath *ip(NSUInteger s, NSUInteger i) {
    return [[NSIndexPath indexPathWithIndex:s] indexPathByAddingIndex:i];
}

int main(void)
{
    @autoreleasepool {
        NSIndexPath *a = ip(0, 1), *b = ip(0, 2);

        NSCollectionViewUpdateItem *del = [[NSCollectionViewUpdateItem alloc] initWithOldIndexPath:a newIndexPath:nil];
        CHECK(del.updateAction == NSCollectionUpdateActionDelete, "old only -> Delete");
        CHECK(del.indexPathBeforeUpdate == a && del.indexPathAfterUpdate == nil, "delete paths");

        NSCollectionViewUpdateItem *ins = [[NSCollectionViewUpdateItem alloc] initWithOldIndexPath:nil newIndexPath:b];
        CHECK(ins.updateAction == NSCollectionUpdateActionInsert, "new only -> Insert");
        CHECK(ins.indexPathAfterUpdate == b, "insert path");

        NSCollectionViewUpdateItem *mov = [[NSCollectionViewUpdateItem alloc] initWithOldIndexPath:a newIndexPath:b];
        CHECK(mov.updateAction == NSCollectionUpdateActionMove, "different paths -> Move");

        NSCollectionViewUpdateItem *rel = [[NSCollectionViewUpdateItem alloc] initWithOldIndexPath:a newIndexPath:ip(0,1)];
        CHECK(rel.updateAction == NSCollectionUpdateActionReload, "equal paths -> Reload");

        NSCollectionViewUpdateItem *non = [[NSCollectionViewUpdateItem alloc] initWithOldIndexPath:nil newIndexPath:nil];
        CHECK(non.updateAction == NSCollectionUpdateActionNone, "neither -> None");

        /* copy */
        NSCollectionViewUpdateItem *c = [mov copy];
        CHECK(c.updateAction == NSCollectionUpdateActionMove, "copy keeps action");
        CHECK(c.indexPathBeforeUpdate == a && c.indexPathAfterUpdate == b, "copy keeps paths");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
