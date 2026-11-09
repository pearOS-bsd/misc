/* test_nshelpmanager.m — NSHelpManager context-help registry. */
#import "../src/NSHelpManager.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSHelpManager *hm = [NSHelpManager sharedHelpManager];
        CHECK(hm != nil, "shared help manager exists");
        CHECK([NSHelpManager sharedHelpManager] == hm, "shared is a singleton");

        /* context-help mode flag */
        CHECK(!NSHelpManager.isContextHelpModeActive, "help mode inactive by default");
        NSHelpManager.contextHelpModeActive = YES;
        CHECK(NSHelpManager.isContextHelpModeActive, "help mode activated");
        NSHelpManager.contextHelpModeActive = NO;
        CHECK(!NSHelpManager.isContextHelpModeActive, "help mode deactivated");

        /* register help for an object */
        id control = [NSObject new];
        NSAttributedString *help = [[NSAttributedString alloc] initWithString:@"Click to save."];
        CHECK([hm contextHelpForObject:control] == nil, "no help registered initially");
        [hm setContextHelp:help forObject:control];
        CHECK([[hm contextHelpForObject:control].string isEqualToString:@"Click to save."],
              "help retrieved for the object");

        /* another object has no help */
        id other = [NSObject new];
        CHECK([hm contextHelpForObject:other] == nil, "unrelated object has no help");

        /* remove */
        [hm removeContextHelpForObject:control];
        CHECK([hm contextHelpForObject:control] == nil, "help removed");

        /* nil object is tolerated */
        id nilObj = nil;
        [hm setContextHelp:help forObject:nilObj];
        CHECK([hm contextHelpForObject:nilObj] == nil, "nil object -> nil help, no crash");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
