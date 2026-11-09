/* test_nssearchtoolbaritem.m — NSSearchToolbarItem. */
#import "../src/NSSearchToolbarItem.h"
#import "../src/NSToolbarItem.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSSearchToolbarItem *item = [[NSSearchToolbarItem alloc] initWithItemIdentifier:@"search"];
        CHECK([item isKindOfClass:[NSToolbarItem class]], "is an NSToolbarItem");
        CHECK([item.itemIdentifier isEqualToString:@"search"], "identifier inherited");
        CHECK(item.resignsFirstResponderWithCancel, "resignsFirstResponderWithCancel default YES");
        CHECK(!item.isEditing, "not editing by default");
        CHECK(item.preferredWidthForSearchField == 0.0, "default preferred width 0");

        item.preferredWidthForSearchField = 240.0;
        CHECK(item.preferredWidthForSearchField == 240.0, "preferred width set");
        item.resignsFirstResponderWithCancel = NO;
        CHECK(!item.resignsFirstResponderWithCancel, "resign flag cleared");

        /* editing state */
        [item beginEditing];
        CHECK(item.isEditing, "beginEditing sets editing");
        [item endEditing];
        CHECK(!item.isEditing, "endEditing clears editing");

        /* explicit searchField */
        id field = [NSObject new];
        item.searchField = field;
        CHECK(item.searchField == field, "explicit search field stored");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
