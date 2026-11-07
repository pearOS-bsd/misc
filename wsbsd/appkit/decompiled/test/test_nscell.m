/*
 * test_nscell.m — behaviour tests for the 1:1 NSCell flag/state core.
 * state tri-state, enabled, highlighted, type, and the throwing target/action/
 * tag stubs.
 */
#import "../src/NSCell.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        NSCell *c = [[NSCell alloc] init];

        /* --- state tri-state --- */
        CHECK(c.state == NSControlStateValueOff, "state defaults Off");
        c.state = NSControlStateValueOn;
        CHECK(c.state == NSControlStateValueOn, "state On round-trips");
        c.state = NSControlStateValueMixed;
        CHECK(c.state == NSControlStateValueMixed, "state Mixed round-trips (-1)");
        c.state = NSControlStateValueOff;
        CHECK(c.state == NSControlStateValueOff, "state back to Off clears mixed+on");

        /* --- enabled --- */
        CHECK(c.isEnabled == YES, "enabled defaults YES");
        c.enabled = NO;
        CHECK(c.isEnabled == NO, "enabled false round-trips");
        c.enabled = YES;
        CHECK(c.isEnabled == YES, "enabled true round-trips");

        /* --- highlighted --- */
        CHECK(c.isHighlighted == NO, "highlighted defaults NO");
        c.highlighted = YES;
        CHECK(c.isHighlighted == YES, "highlighted round-trips");

        /* enabled/highlighted/state are independent bits */
        c.enabled = NO; c.highlighted = YES; c.state = NSControlStateValueOn;
        CHECK(c.isEnabled == NO && c.isHighlighted == YES && c.state == NSControlStateValueOn,
              "enabled/highlighted/state are independent");

        /* --- type --- */
        CHECK(c.type == NSNullCellType, "type defaults Null");
        c.type = NSTextCellType;
        CHECK(c.type == NSTextCellType, "type Text round-trips");
        c.type = NSImageCellType;
        CHECK(c.type == NSImageCellType, "type Image round-trips");
        /* setting type does not disturb the other flag bits */
        CHECK(c.isHighlighted == YES && c.state == NSControlStateValueOn,
              "setType leaves other flags intact");

        /* --- target/action/tag stubs --- */
        CHECK(c.target == nil, "NSCell target stub returns nil");
        CHECK(c.action == NULL, "NSCell action stub returns NULL");
        CHECK(c.tag == -1, "NSCell tag stub returns -1");

        BOOL threwTarget = NO, threwAction = NO, threwTag = NO;
        @try { c.target = c; } @catch (NSException *e) { threwTarget = YES; }
        @try { c.action = @selector(init); } @catch (NSException *e) { threwAction = YES; }
        @try { c.tag = 7; } @catch (NSException *e) { threwTag = YES; }
        CHECK(threwTarget, "NSCell setTarget: raises");
        CHECK(threwAction, "NSCell setAction: raises");
        CHECK(threwTag, "NSCell setTag: raises");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
