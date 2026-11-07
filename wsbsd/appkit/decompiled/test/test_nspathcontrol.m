/* test_nspathcontrol.m — NSPathControl over NSPathCell. */
#import "../src/NSPathControl.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSPathControl *pc = [[NSPathControl alloc] initWithFrame:CGRectMake(0, 0, 240, 22)];
        CHECK([pc.cell isKindOfClass:[NSPathCell class]], "cell is NSPathCell");

        CHECK(pc.pathStyle == NSPathStyleStandard, "default pathStyle standard");
        pc.pathStyle = NSPathStylePopUp;
        CHECK(pc.pathStyle == NSPathStylePopUp, "pathStyle round-trips");

        NSURL *u = [NSURL fileURLWithPath:@"/Users/x/Documents"];
        pc.URL = u;
        CHECK([pc.URL isEqual:u], "URL round-trips");
        CHECK([((NSPathCell *)pc.cell).URL isEqual:u], "URL stored on the cell");

        pc.editable = YES;
        CHECK(pc.isEditable, "editable delegates to the cell (NSCell bit)");
        pc.editable = NO;
        CHECK(!pc.isEditable, "editable cleared");

        CHECK([pc isKindOfClass:[NSControl class]], "NSPathControl is an NSControl");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
