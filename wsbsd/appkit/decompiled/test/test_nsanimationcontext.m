/* test_nsanimationcontext.m — NSAnimationContext grouping stack. */
#import "../src/NSAnimationContext.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSAnimationContext *base = [NSAnimationContext currentContext];
        CHECK(base != nil, "base current context exists");
        CHECK(base.duration == 0.25, "default duration 0.25");

        /* grouping pushes a new context inheriting duration */
        base.duration = 0.5;
        [NSAnimationContext beginGrouping];
        NSAnimationContext *inner = [NSAnimationContext currentContext];
        CHECK(inner != base, "beginGrouping pushes a new context");
        CHECK(inner.duration == 0.5, "inner inherits the current duration");
        inner.duration = 1.0;
        CHECK([NSAnimationContext currentContext].duration == 1.0, "inner duration independent");
        [NSAnimationContext endGrouping];
        CHECK([NSAnimationContext currentContext] == base, "endGrouping pops back to base");
        CHECK(base.duration == 0.5, "base duration unaffected by inner changes");

        /* runAnimationGroup provides the context and fires completion */
        __block int ran = 0, completed = 0;
        __block NSTimeInterval seen = -1;
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *ctx) {
            ran++;
            ctx.duration = 0.1;
            seen = ctx.duration;
        } completionHandler:^{ completed++; }];
        CHECK(ran == 1, "changes block ran once");
        CHECK(seen == 0.1, "changes block saw its own context");
        CHECK(completed == 1, "completion handler fired");
        CHECK([NSAnimationContext currentContext] == base, "stack balanced after runAnimationGroup");

        /* nested grouping */
        [NSAnimationContext beginGrouping];
        [NSAnimationContext beginGrouping];
        [NSAnimationContext endGrouping];
        [NSAnimationContext endGrouping];
        CHECK([NSAnimationContext currentContext] == base, "nested begin/end balanced");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
