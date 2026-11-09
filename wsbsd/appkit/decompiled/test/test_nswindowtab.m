/* test_nswindowtab.m — NSWindowTab value object. */
#import "../src/NSWindowTab.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSWindowTab *tab = [[NSWindowTab alloc] init];
        CHECK([tab.title isEqualToString:@""], "title defaults to empty (null_resettable)");
        CHECK(!tab.showIcon, "showIcon off by default");
        CHECK(tab.toolTip == nil, "no tooltip by default");

        tab.title = @"Document 1";
        CHECK([tab.title isEqualToString:@"Document 1"], "title set");
        tab.toolTip = @"Edited";
        CHECK([tab.toolTip isEqualToString:@"Edited"], "tooltip set");

        NSString *nilTitle = nil;
        tab.title = nilTitle;
        CHECK([tab.title isEqualToString:@""], "nil title resets to empty");

        tab.attributedTitle = [[NSAttributedString alloc] initWithString:@"Bold"];
        CHECK([tab.attributedTitle.string isEqualToString:@"Bold"], "attributed title set");

        tab.showIcon = YES;
        id img = [NSObject new];
        tab.image = img;
        id acc = [NSObject new];
        tab.accessoryView = acc;
        CHECK(tab.showIcon, "showIcon set");
        CHECK(tab.image == img, "image set");
        CHECK(tab.accessoryView == acc, "accessory view set");

        id win = [NSObject new];
        tab.window = win;
        CHECK(tab.window == win, "window back-link set");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
