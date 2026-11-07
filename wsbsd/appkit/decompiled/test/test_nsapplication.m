/*
 * test_nsapplication.m — NSApplication core: shared singleton + NSApp, delegate,
 * mainMenu kind-check, running flag, and action dispatch (sendAction:to:from:,
 * targetForAction:to:from:).
 */
#import "../src/NSApplication.h"
#import "../src/NSMenu.h"

@interface Receiver : NSObject
@property (nonatomic) id lastSender;
@property (nonatomic) BOOL fired;
@end
@implementation Receiver
- (void)doStuff:(id)sender { self.fired = YES; self.lastSender = sender; }
@end

@interface AppDel : NSObject
- (void)delegateAction:(id)sender;
@property (nonatomic) BOOL fired;
@end
@implementation AppDel
- (void)delegateAction:(id)sender { self.fired = YES; }
@end

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        CHECK(app != nil, "sharedApplication returns an instance");
        CHECK([NSApplication sharedApplication] == app, "sharedApplication is a singleton");
        CHECK(NSApp == app, "NSApp points at the shared application");
        CHECK(app.isRunning == NO, "app not running before -run");
        CHECK(app.windows.count == 0, "no windows yet");

        /* delegate (weak) */
        AppDel *del = [AppDel new];
        app.delegate = del;
        CHECK(app.delegate == del, "delegate round-trips");

        /* mainMenu kind-check */
        NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Main"];
        app.mainMenu = menu;
        CHECK(app.mainMenu == menu, "mainMenu accepts an NSMenu");
        app.mainMenu = (NSMenu *)[NSObject new];   /* not an NSMenu */
        CHECK(app.mainMenu == menu, "mainMenu rejects a non-NSMenu");

        /* sendAction with an explicit target */
        Receiver *r = [Receiver new];
        id snd = [NSObject new];
        BOOL ok = [app sendAction:@selector(doStuff:) to:r from:snd];
        CHECK(ok && r.fired && r.lastSender == snd, "sendAction fires on an explicit target with sender");

        /* target that does not respond */
        CHECK([app sendAction:@selector(doStuff:) to:[NSObject new] from:nil] == NO,
              "sendAction returns NO when the target does not respond");

        /* nil target resolves to the app delegate */
        id t = [app targetForAction:@selector(delegateAction:) to:nil from:nil];
        CHECK(t == del, "targetForAction nil-target resolves to the delegate");
        BOOL ok2 = [app sendAction:@selector(delegateAction:) to:nil from:nil];
        CHECK(ok2 && del.fired, "sendAction nil-target fires on the delegate");

        /* NULL action */
        SEL noAction = NULL;
        CHECK([app sendAction:noAction to:r from:nil] == NO, "NULL action returns NO");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
