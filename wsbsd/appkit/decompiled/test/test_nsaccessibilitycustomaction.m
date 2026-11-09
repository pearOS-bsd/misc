/* test_nsaccessibilitycustomaction.m — NSAccessibilityCustomAction. */
#import "../src/NSAccessibilityCustomAction.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        __block int ran = 0;
        NSAccessibilityCustomAction *h = [[NSAccessibilityCustomAction alloc] initWithName:@"Toggle"
                                                                                   handler:^BOOL{ ran++; return YES; }];
        CHECK([h.name isEqualToString:@"Toggle"], "name from handler init");
        CHECK(h.handler != nil, "handler stored");
        CHECK(h.target == nil && h.selector == NULL, "handler action has no target/selector");
        CHECK(h.handler(), "handler returns YES");
        CHECK(ran == 1, "handler ran");

        id tgt = [NSObject new];
        NSAccessibilityCustomAction *ts = [[NSAccessibilityCustomAction alloc] initWithName:@"Delete"
                                                                                    target:tgt
                                                                                  selector:@selector(copy)];
        CHECK([ts.name isEqualToString:@"Delete"], "name from target/selector init");
        CHECK(ts.target == tgt, "target stored");
        CHECK(ts.selector == @selector(copy), "selector stored");
        CHECK(ts.handler == nil, "target action has no handler");

        ts.name = @"Remove";
        CHECK([ts.name isEqualToString:@"Remove"], "name settable");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
