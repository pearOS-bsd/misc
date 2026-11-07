/*
 * test_nsmenuitem.m — NSMenuItem core: designated init, title/action/target/
 * tag/keyEquivalent, tri-state, enabled, and the separator item.
 */
#import "../src/NSMenuItem.h"
#import <objc/runtime.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        NSMenuItem *it = [[NSMenuItem alloc] initWithTitle:@"Open" action:@selector(description) keyEquivalent:@"o"];
        CHECK([it.title isEqualToString:@"Open"], "init sets title");
        CHECK(sel_isEqual(it.action, @selector(description)), "init sets action");
        CHECK([it.keyEquivalent isEqualToString:@"o"], "init sets keyEquivalent");
        CHECK(it.isEnabled == YES, "item enabled by default");
        CHECK(it.isSeparatorItem == NO, "ordinary item is not a separator");

        /* target is weak */
        id obj = [NSObject new];
        it.target = obj;
        CHECK(it.target == obj, "target round-trips");

        /* tag */
        it.tag = 5;
        CHECK(it.tag == 5, "tag round-trips");

        /* tri-state */
        CHECK(it.state == NSControlStateValueOff, "state defaults Off");
        it.state = NSControlStateValueOn;
        CHECK(it.state == NSControlStateValueOn, "state On");
        it.state = NSControlStateValueMixed;
        CHECK(it.state == NSControlStateValueMixed, "state Mixed");
        it.state = NSControlStateValueOff;
        CHECK(it.state == NSControlStateValueOff, "state Off again");

        /* title setter early-out still yields the value */
        it.title = @"Save";
        CHECK([it.title isEqualToString:@"Save"], "title updates");

        /* enabled */
        it.enabled = NO;
        CHECK(it.isEnabled == NO, "enabled round-trips");

        /* separator item */
        NSMenuItem *sep = [NSMenuItem separatorItem];
        CHECK(sep.isSeparatorItem == YES, "separatorItem is a separator");

        /* weak target clears when the object goes away */
        @autoreleasepool {
            id tmp = [NSObject new];
            it.target = tmp;
            CHECK(it.target == tmp, "weak target held while alive");
        }
        CHECK(it.target == nil, "weak target cleared after dealloc");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
