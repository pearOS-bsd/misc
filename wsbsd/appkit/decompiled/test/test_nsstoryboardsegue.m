/* test_nsstoryboardsegue.m — NSStoryboardSegue value + perform handler. */
#import "../src/NSStoryboardSegue.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        id src = [NSObject new];
        id dst = [NSObject new];
        __block int performed = 0;
        NSStoryboardSegue *seg = [NSStoryboardSegue segueWithIdentifier:@"showDetail"
                                                                 source:src
                                                            destination:dst
                                                         performHandler:^{ performed++; }];
        CHECK([seg.identifier isEqualToString:@"showDetail"], "identifier stored");
        CHECK(seg.sourceController == src, "source stored");
        CHECK(seg.destinationController == dst, "destination stored");
        CHECK(seg.performHandler != nil, "perform handler stored");

        [seg perform];
        CHECK(performed == 1, "perform runs the perform handler");
        [seg perform];
        CHECK(performed == 2, "perform can run again");

        /* prepare handler settable */
        __block int prepared = 0;
        seg.prepareHandler = ^{ prepared++; };
        CHECK(seg.prepareHandler != nil, "prepare handler set");
        seg.prepareHandler();
        CHECK(prepared == 1, "prepare handler callable");

        /* plain segue with no handler: perform is a no-op, no crash */
        NSStoryboardSegue *plain = [[NSStoryboardSegue alloc] initWithIdentifier:@"x" source:src destination:dst];
        [plain perform];
        CHECK([plain.identifier isEqualToString:@"x"], "plain segue identifier");
        CHECK(plain.performHandler == nil, "plain segue has no perform handler");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
