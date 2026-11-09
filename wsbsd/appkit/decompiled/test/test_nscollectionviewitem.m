/* test_nscollectionviewitem.m — NSCollectionViewItem flags + inheritance. */
#import "../src/NSCollectionViewItem.h"
#import "../src/NSView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSCollectionViewItem *item = [[NSCollectionViewItem alloc] init];
        CHECK([item isKindOfClass:[NSViewController class]], "is an NSViewController");
        CHECK(!item.isSelected, "not selected by default");
        CHECK(item.highlightState == NSCollectionViewItemHighlightNone, "no highlight by default");

        item.selected = YES;
        item.highlightState = NSCollectionViewItemHighlightForSelection;
        CHECK(item.isSelected, "selected set");
        CHECK(item.highlightState == NSCollectionViewItemHighlightForSelection, "highlight set");

        /* represented object inherited from NSViewController */
        item.representedObject = @"model";
        CHECK([item.representedObject isEqualToString:@"model"], "representedObject inherited");

        /* view inherited (lazy) */
        CHECK(!item.isViewLoaded, "view not loaded yet");
        (void)item.view;
        CHECK(item.isViewLoaded, "view lazily loaded from NSViewController");

        /* outlets + back-link (weak) */
        id cv = [NSObject new];
        id iv = [NSObject new];
        id tf = [NSObject new];
        item.collectionView = cv;
        item.imageView = iv;
        item.textField = tf;
        CHECK(item.collectionView == cv, "collectionView back-link");
        CHECK(item.imageView == iv, "imageView outlet");
        CHECK(item.textField == tf, "textField outlet");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
