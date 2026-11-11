/* test_nsworkspaceopenconfiguration.m — behaviour checks for the open-config value object */
#import "../src/NSWorkspaceOpenConfiguration.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSWorkspaceOpenConfiguration *c = [NSWorkspaceOpenConfiguration configuration];
        CHECK(c != nil, "configuration factory returns an object");

        /* measured defaults */
        CHECK(c.promptsUserIfNeeded, "promptsUserIfNeeded default YES");
        CHECK(c.addsToRecentItems, "addsToRecentItems default YES");
        CHECK(c.activates, "activates default YES");
        CHECK(!c.hides, "hides default NO");
        CHECK(!c.hidesOthers, "hidesOthers default NO");
        CHECK(!c.isForPrinting, "forPrinting default NO");
        CHECK(!c.createsNewApplicationInstance, "createsNewApplicationInstance default NO");
        CHECK(c.allowsRunningApplicationSubstitution, "allowsRunningApplicationSubstitution default YES");
        CHECK(!c.requiresUniversalLinks, "requiresUniversalLinks default NO");
        CHECK(c.architecture == -1, "architecture default -1");
        CHECK(c.arguments.count == 0 && c.environment.count == 0, "arguments/environment empty");
        CHECK(c.appleEvent == nil, "appleEvent nil");

        /* setters */
        c.hides = YES; c.activates = NO; c.architecture = 0x0100000c;
        CHECK(c.hides && !c.activates && c.architecture == 0x0100000c, "scalar setters");
        c.forPrinting = YES;
        CHECK(c.isForPrinting, "forPrinting setter via getter=isForPrinting");

        /* arguments/environment copy semantics */
        NSMutableArray *args = [@[@"--a"] mutableCopy];
        c.arguments = args;
        [args addObject:@"--b"];
        CHECK(c.arguments.count == 1, "arguments snapshot-copied");
        NSMutableDictionary *env = [@{@"K": @"V"} mutableCopy];
        c.environment = env;
        [env setObject:@"W" forKey:@"K2"];
        CHECK(c.environment.count == 1, "environment snapshot-copied");

        /* nil arguments/environment coerce to empty */
        NSArray *nilArgs = nil; NSDictionary *nilEnv = nil;
        c.arguments = nilArgs;
        c.environment = nilEnv;
        CHECK(c.arguments.count == 0 && c.environment.count == 0, "nil args/env coerce to empty");

        /* NSCopying carries all state */
        c.hidesOthers = YES; c.requiresUniversalLinks = YES; c.arguments = @[@"x", @"y"];
        NSWorkspaceOpenConfiguration *cp = [c copy];
        CHECK(cp.hides && !cp.activates && cp.hidesOthers && cp.requiresUniversalLinks
              && cp.architecture == 0x0100000c && cp.isForPrinting
              && cp.arguments.count == 2, "copy carries full state");
        CHECK(cp != c, "copy is a distinct object");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
