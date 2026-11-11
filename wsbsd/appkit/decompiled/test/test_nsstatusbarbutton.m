/* test_nsstatusbarbutton.m — behaviour checks for NSStatusBarButton core */
#import "../src/NSStatusBarButton.h"
#import "../src/NSMenu.h"
#import "../src/NSApplication.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSStatusBarButton *b = [[NSStatusBarButton alloc] initWithFrame:NSMakeRect(0, 0, 24, 22)];
        CHECK([b isKindOfClass:[NSButton class]], "is an NSButton");

        /* default */
        CHECK(!b.appearsDisabled, "appearsDisabled default NO");

        /* appearsDisabled toggles without disabling interaction (still enabled) */
        b.appearsDisabled = YES;
        CHECK(b.appearsDisabled, "appearsDisabled set YES");
        b.appearsDisabled = NO;
        CHECK(!b.appearsDisabled, "appearsDisabled back to NO");

        /* doubleAction */
        b.doubleAction = @selector(copy);
        CHECK(b.doubleAction == @selector(copy), "doubleAction stored");

        /* statusMenu */
        NSMenu *m = [[NSMenu alloc] initWithTitle:@"Status"];
        b.statusMenu = m;
        CHECK(b.statusMenu == m, "statusMenu stored");
        b.statusMenu = nil;
        CHECK(b.statusMenu == nil, "statusMenu cleared");

        /* inherits NSButton title behaviour */
        b.title = @"S";
        CHECK([b.title isEqual:@"S"], "inherits NSButton title");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
