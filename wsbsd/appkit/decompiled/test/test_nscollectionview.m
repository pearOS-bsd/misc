/* test_nscollectionview.m */
#import "../src/NSCollectionView.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface DS : NSObject <NSCollectionViewDataSource>
@property NSInteger sections; @property NSInteger items;
@end
@implementation DS
- (NSInteger)collectionView:(NSCollectionView *)cv numberOfItemsInSection:(NSInteger)s { return self.items; }
- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)cv { return self.sections; }
@end

int main(void) {
    @autoreleasepool {
        NSCollectionView *c = [[NSCollectionView alloc] initWithFrame:NSMakeRect(0,0,300,300)];
        CHECK([c isKindOfClass:[NSView class]], "is-a NSView");

        /* measured defaults */
        CHECK(!c.isSelectable, "selectable NO default");
        CHECK(!c.allowsMultipleSelection, "allowsMultipleSelection NO default");
        CHECK(c.allowsEmptySelection, "allowsEmptySelection YES default");
        CHECK(c.collectionViewLayout == nil, "layout nil default");
        CHECK(c.dataSource == nil, "dataSource nil default");
        CHECK(c.numberOfSections == 1, "numberOfSections 1 with no data source (measured)");
        CHECK([c numberOfItemsInSection:0] == 0, "no items without a data source");
        CHECK(c.selectionIndexPaths.count == 0, "empty selection default");

        /* data source drives counts */
        DS *ds = [DS new]; ds.sections = 3; ds.items = 7;
        c.dataSource = ds;
        CHECK(c.numberOfSections == 3, "numberOfSections from data source");
        CHECK([c numberOfItemsInSection:0] == 7, "numberOfItemsInSection from data source");

        /* setters */
        c.selectable = YES; CHECK(c.isSelectable, "selectable set");
        c.allowsMultipleSelection = YES; CHECK(c.allowsMultipleSelection, "allowsMultipleSelection set");
        NSIndexPath *ip = [NSIndexPath indexPathWithIndex:0];
        c.selectionIndexPaths = [NSSet setWithObject:ip];
        CHECK(c.selectionIndexPaths.count == 1, "selectionIndexPaths set");
        id layout = [NSObject new]; c.collectionViewLayout = (id)layout;
        CHECK((id)c.collectionViewLayout == layout, "layout set");

        [c reloadData];  /* stage2 no-op, must not crash */
        CHECK(1, "reloadData safe");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
