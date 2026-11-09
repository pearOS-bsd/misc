/* test_nsmenutoolbaritem.m — NSMenuToolbarItem. */
#import "../src/NSMenuToolbarItem.h"
#import "../src/NSToolbarItem.h"
#import "../src/NSMenu.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSMenuToolbarItem *item = [[NSMenuToolbarItem alloc] initWithItemIdentifier:@"actions"];
        CHECK([item isKindOfClass:[NSToolbarItem class]], "is an NSToolbarItem");
        CHECK([item.itemIdentifier isEqualToString:@"actions"], "identifier inherited");
        CHECK(item.showsIndicator, "showsIndicator default YES");
        CHECK(item.menu == nil, "no menu by default");

        NSMenu *m = [[NSMenu alloc] initWithTitle:@"Actions"];
        item.menu = m;
        CHECK(item.menu == m, "menu set");
        CHECK([item.menu.title isEqualToString:@"Actions"], "menu accessible");

        item.showsIndicator = NO;
        CHECK(!item.showsIndicator, "showsIndicator cleared");

        id tgt = [NSObject new];
        item.target = tgt;
        item.action = @selector(copy:);
        CHECK(item.target == tgt, "target set");
        CHECK(item.action == @selector(copy:), "action set");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
