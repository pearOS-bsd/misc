/* test_nstrackingarea.m — NSTrackingArea value object + options validation. */
#import "../src/NSTrackingArea.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        id owner = [NSObject new];
        NSDictionary *info = @{ @"k": @"v" };
        NSTrackingAreaOptions opts = NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow;
        NSTrackingArea *ta = [[NSTrackingArea alloc] initWithRect:CGRectMake(1, 2, 30, 40)
                                                          options:opts owner:owner userInfo:info];
        CHECK(ta != nil, "valid tracking area built");
        CHECK(CGRectEqualToRect(ta.rect, CGRectMake(1, 2, 30, 40)), "rect stored");
        CHECK(ta.options == opts, "options stored");
        CHECK(ta.owner == owner, "owner stored");
        CHECK([ta.userInfo[@"k"] isEqualToString:@"v"], "userInfo stored");

        /* missing tracking type -> raise */
        BOOL raised = NO;
        @try {
            (void)[[NSTrackingArea alloc] initWithRect:CGRectZero
                                               options:NSTrackingActiveInKeyWindow owner:owner userInfo:nil];
        } @catch (NSException *e) { raised = YES; }
        CHECK(raised, "no tracking type raises");

        /* missing active option -> raise */
        raised = NO;
        @try {
            (void)[[NSTrackingArea alloc] initWithRect:CGRectZero
                                               options:NSTrackingMouseMoved owner:owner userInfo:nil];
        } @catch (NSException *e) { raised = YES; }
        CHECK(raised, "no active option raises");

        /* ActiveAlways + CursorUpdate is valid */
        NSTrackingArea *ta2 = [[NSTrackingArea alloc] initWithRect:CGRectZero
                                                           options:NSTrackingCursorUpdate | NSTrackingActiveAlways
                                                             owner:owner userInfo:nil];
        CHECK(ta2 != nil, "cursorUpdate + activeAlways valid");
        CHECK(ta2.userInfo == nil, "nil userInfo allowed");

        /* copy + equality */
        NSTrackingArea *cp = [ta copy];
        CHECK([cp isEqual:ta], "copy equal to original");
        CHECK(![ta isEqual:ta2], "different areas not equal");

        /* owner held weakly: options/rect still valid regardless */
        CHECK(ta.options == opts, "options stable");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
