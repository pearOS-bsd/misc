/* test_nstouchbar.m — NSTouchBar item resolution + caching. */
#import "../src/NSTouchBar.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

@interface FakeDelegate : NSObject <NSTouchBarDelegate>
@property int calls;
@end
@implementation FakeDelegate
- (NSTouchBarItem *)touchBar:(NSTouchBar *)tb makeItemForIdentifier:(NSTouchBarItemIdentifier)ident
{
    _calls++;
    if ([ident isEqualToString:@"known"]) return (NSTouchBarItem *)[NSObject new];
    return nil;
}
@end

int main(void)
{
    @autoreleasepool {
        NSTouchBar *tb = [[NSTouchBar alloc] init];
        CHECK(tb.itemIdentifiers.count == 0, "no default identifiers initially");
        CHECK([tb itemForIdentifier:@"x"] == nil, "no delegate -> nil item");

        tb.defaultItemIdentifiers = @[ @"a", @"b", @"known" ];
        CHECK(tb.itemIdentifiers.count == 3, "default identifiers set");
        CHECK([tb.itemIdentifiers[0] isEqualToString:@"a"], "identifier order preserved");

        tb.principalItemIdentifier = @"known";
        CHECK([tb.principalItemIdentifier isEqualToString:@"known"], "principal item set");

        FakeDelegate *d = [FakeDelegate new];
        tb.delegate = d;
        id item = [tb itemForIdentifier:@"known"];
        CHECK(item != nil, "delegate makes a known item");
        CHECK(d.calls == 1, "delegate asked once");

        /* cached: delegate not asked again */
        id item2 = [tb itemForIdentifier:@"known"];
        CHECK(item2 == item, "item is cached");
        CHECK(d.calls == 1, "delegate not asked again for a cached item");

        /* unknown: delegate returns nil, asked once, then remembered as a miss */
        CHECK([tb itemForIdentifier:@"missing"] == nil, "unknown item -> nil");
        CHECK(d.calls == 2, "delegate asked for the unknown item");
        CHECK([tb itemForIdentifier:@"missing"] == nil, "still nil");
        CHECK(d.calls == 2, "delegate not re-asked for a known miss");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
