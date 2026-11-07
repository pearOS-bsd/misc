/*
 * test_nscontrol.m — NSControl cell-backed core: cell creation from +cellClass,
 * isEnabled, and target/action/tag delegated to the action cell.
 */
#import "../src/NSControl.h"
#import "../src/NSActionCell.h"
#import "../src/NSApplication.h"
#import <objc/runtime.h>

/* A concrete control whose cell is an NSActionCell, like real controls. */
@interface TestControl : NSControl @end
@implementation TestControl
+ (Class)cellClass { return [NSActionCell class]; }
@end

/* action receiver for the end-to-end dispatch test */
@interface Clicker : NSObject
@property (nonatomic) BOOL clicked;
@property (nonatomic) id sender;
@end
@implementation Clicker
- (void)clicked:(id)sender { self.clicked = YES; self.sender = sender; }
@end

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        TestControl *ctl = [[TestControl alloc] initWithFrame:CGRectMake(0, 0, 80, 24)];

        /* cell built from +cellClass */
        CHECK([ctl.cell isKindOfClass:[NSActionCell class]],
              "initWithFrame builds the cell from +cellClass");
        /* cell points back at the control */
        CHECK([(NSActionCell *)ctl.cell controlView] == ctl, "cell.controlView points back at control");

        /* enabled default + round-trip (delegates to cell) */
        CHECK(ctl.isEnabled == YES, "control enabled by default");
        ctl.enabled = NO;
        CHECK(ctl.isEnabled == NO, "setEnabled delegates to cell");
        CHECK(ctl.cell.isEnabled == NO, "cell reflects the control's enabled state");
        ctl.enabled = YES;

        /* target/action/tag delegate to the action cell */
        id obj = [NSObject new];
        ctl.target = obj;
        ctl.action = @selector(description);
        ctl.tag = 99;
        CHECK(ctl.target == obj, "target delegates to cell");
        CHECK(sel_isEqual(ctl.action, @selector(description)), "action delegates to cell");
        CHECK(ctl.tag == 99, "tag delegates to cell");
        CHECK([(NSActionCell *)ctl.cell target] == obj, "the cell actually holds the target");

        /* a base NSControl has no cell: falls back to _conFlags for enabled */
        NSControl *bare = [[NSControl alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        CHECK(bare.cell == nil, "base NSControl has no cell (nil cellClass)");
        CHECK(bare.isEnabled == YES, "cell-less control reads enabled from _conFlags");
        CHECK(bare.target == nil, "cell-less control target is nil");

        /* replace the cell */
        NSActionCell *fresh = [[NSActionCell alloc] init];
        ctl.cell = fresh;
        CHECK(ctl.cell == fresh, "cell can be replaced");

        /* end-to-end: control fires its action on its target through NSApp */
        (void)[NSApplication sharedApplication];
        TestControl *btn = [[TestControl alloc] initWithFrame:CGRectMake(0, 0, 40, 20)];
        Clicker *clk = [Clicker new];
        btn.target = clk;
        btn.action = @selector(clicked:);
        BOOL fired = [btn sendAction:btn.action to:btn.target];
        CHECK(fired && clk.clicked, "sendAction:to: dispatches through NSApp to the target");
        CHECK(clk.sender == btn, "target receives the control as sender");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
