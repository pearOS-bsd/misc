/* test_nsalert.m — NSAlert: text, style, buttons (composes NSButton). */
#import "../src/NSAlert.h"
#import <objc/runtime.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSAlert *a = [[NSAlert alloc] init];
        CHECK([a.messageText isEqualToString:@""], "messageText defaults empty");
        CHECK(a.alertStyle == NSAlertStyleWarning, "default style warning");
        CHECK(a.buttons.count == 0, "no buttons to start");

        a.messageText = @"Delete this file?";
        a.informativeText = @"This cannot be undone.";
        CHECK([a.messageText isEqualToString:@"Delete this file?"], "messageText round-trips");
        CHECK([a.informativeText isEqualToString:@"This cannot be undone."], "informativeText round-trips");

        a.alertStyle = NSAlertStyleCritical;
        CHECK(a.alertStyle == NSAlertStyleCritical, "alertStyle round-trips");
        a.showsHelp = YES;
        CHECK(a.showsHelp, "showsHelp round-trips");

        /* addButtonWithTitle builds real NSButtons */
        NSButton *ok = [a addButtonWithTitle:@"Delete"];
        NSButton *cancel = [a addButtonWithTitle:@"Cancel"];
        CHECK([ok isKindOfClass:[NSButton class]], "addButtonWithTitle returns an NSButton");
        CHECK([ok.title isEqualToString:@"Delete"], "button has the title");
        CHECK(a.buttons.count == 2 && a.buttons[0] == ok && a.buttons[1] == cancel, "buttons in order");
        CHECK(ok.tag == 1000, "first button tag == NSAlertFirstButtonReturn (1000)");
        CHECK(cancel.tag == 1001, "second button tag == 1001");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
