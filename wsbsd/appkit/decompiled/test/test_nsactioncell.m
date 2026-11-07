/*
 * test_nsactioncell.m — NSActionCell adds real target/action/tag over NSCell's
 * throwing stubs, and inherits NSCell's flag/state core.
 */
#import "../src/NSActionCell.h"
#import <objc/runtime.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        NSActionCell *c = [[NSActionCell alloc] init];

        /* defaults */
        CHECK(c.target == nil, "target defaults nil");
        CHECK(c.action == NULL, "action defaults NULL");
        CHECK(c.tag == 0, "tag defaults 0");

        /* real storage, no throwing (unlike NSCell) */
        id obj = [NSObject new];
        BOOL threw = NO;
        @try {
            c.target = obj;
            c.action = @selector(description);
            c.tag = 42;
        } @catch (NSException *e) { threw = YES; }
        CHECK(!threw, "NSActionCell setters do not raise (override NSCell stubs)");
        CHECK(c.target == obj, "target round-trips");
        CHECK(sel_isEqual(c.action, @selector(description)), "action round-trips");
        CHECK(c.tag == 42, "tag round-trips");

        /* target is non-retained (assign) — clearing our ref must not have been
         * the cell's responsibility; just confirm it holds what we set. */
        c.target = nil;
        CHECK(c.target == nil, "target can be cleared");

        /* inherits NSCell flag/state core */
        c.state = NSControlStateValueOn;
        CHECK(c.state == NSControlStateValueOn, "inherits NSCell state");
        c.enabled = NO;
        CHECK(c.isEnabled == NO, "inherits NSCell enabled");
        c.type = NSTextCellType;
        CHECK(c.type == NSTextCellType, "inherits NSCell type");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
