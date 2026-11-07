/*
 * test_nsbutton.m — NSButton delegating to NSButtonCell: title, state (on/off/
 * mixed through inherited NSCell _cFlags), bezel style, target/action, and the
 * buttonWithTitle:target:action: convenience constructor.
 */
#import "../src/NSButton.h"
#import <objc/runtime.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        NSButton *b = [[NSButton alloc] initWithFrame:CGRectMake(0, 0, 100, 24)];

        /* cell is an NSButtonCell, built from +cellClass */
        CHECK([b.cell isKindOfClass:[NSButtonCell class]], "button cell is NSButtonCell");

        /* title round-trips through the cell */
        b.title = @"Click Me";
        CHECK([b.title isEqualToString:@"Click Me"], "title round-trips through cell");

        /* state: on/off/mixed via inherited NSCell _cFlags */
        CHECK(b.state == NSControlStateValueOff, "state defaults Off");
        b.state = NSControlStateValueOn;
        CHECK(b.state == NSControlStateValueOn, "state On");
        b.state = NSControlStateValueMixed;
        CHECK(b.state == NSControlStateValueMixed, "state Mixed (-1)");
        b.state = NSControlStateValueOff;
        CHECK(b.state == NSControlStateValueOff, "state back Off");

        /* bezel style */
        b.bezelStyle = NSBezelStyleCircular;
        CHECK(b.bezelStyle == NSBezelStyleCircular, "bezelStyle round-trips");

        /* target/action via NSControl -> NSActionCell */
        id obj = [NSObject new];
        b.target = obj;
        b.action = @selector(description);
        CHECK(b.target == obj, "target round-trips");
        CHECK(sel_isEqual(b.action, @selector(description)), "action round-trips");

        /* enabled via NSControl -> NSCell */
        b.enabled = NO;
        CHECK(b.isEnabled == NO, "enabled round-trips");
        b.enabled = YES;

        /* convenience constructor */
        NSButton *c = [NSButton buttonWithTitle:@"OK" target:obj action:@selector(hash)];
        CHECK([c.title isEqualToString:@"OK"], "buttonWithTitle sets title");
        CHECK(c.target == obj, "buttonWithTitle sets target");
        CHECK(sel_isEqual(c.action, @selector(hash)), "buttonWithTitle sets action");
        CHECK(c.bezelStyle == NSBezelStylePush, "buttonWithTitle uses push bezel");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
