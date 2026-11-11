/* test_nsrunningapplication.m — behaviour checks for NSRunningApplication core */
#import "../src/NSRunningApplication.h"
#import <unistd.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSRunningApplication *cur = [NSRunningApplication currentApplication];
        CHECK(cur != nil, "currentApplication non-nil");
        CHECK(cur == [NSRunningApplication currentApplication], "currentApplication is a singleton");

        /* populated from the live process */
        CHECK(cur.processIdentifier == getpid(), "processIdentifier == getpid()");
        CHECK(cur.isActive, "current app is active");
        CHECK(cur.isFinishedLaunching, "current app finished launching");
        CHECK(!cur.isHidden, "current app not hidden");
        CHECK(!cur.isTerminated, "current app not terminated");
        CHECK(cur.localizedName.length > 0, "localizedName from process name");
        CHECK(cur.launchDate != nil, "launchDate set");

        /* activation policy is a valid enum value (Regular for a plain tool) */
        CHECK(cur.activationPolicy == NSApplicationActivationPolicyRegular
              || cur.activationPolicy == NSApplicationActivationPolicyAccessory
              || cur.activationPolicy == NSApplicationActivationPolicyProhibited, "activationPolicy valid");

        /* executable architecture is the real one */
#if defined(__arm64__) || defined(__aarch64__)
        CHECK(cur.executableArchitecture == 0x0100000c, "executableArchitecture ARM64");
#else
        CHECK(cur.executableArchitecture == 0x01000007, "executableArchitecture x86_64");
#endif

        /* lookup by pid resolves the current app; a foreign pid is stage2 (nil) */
        CHECK([NSRunningApplication runningApplicationWithProcessIdentifier:getpid()] == cur, "lookup by own pid -> current");
        CHECK([NSRunningApplication runningApplicationWithProcessIdentifier:999999] == nil, "foreign pid not resolved (stage2)");

        /* bundle-identifier lookup returns current when it matches */
        if (cur.bundleIdentifier) {
            NSArray *apps = [NSRunningApplication runningApplicationsWithBundleIdentifier:cur.bundleIdentifier];
            CHECK(apps.count == 1 && apps[0] == cur, "bundleID lookup finds current");
        }
        CHECK([NSRunningApplication runningApplicationsWithBundleIdentifier:@"com.nonexistent.zzz"].count == 0,
              "unknown bundleID -> empty");

        /* identity: equal by pid */
        CHECK([cur isEqual:[NSRunningApplication currentApplication]], "equal to itself");
        CHECK(cur.hash == (NSUInteger)getpid(), "hash is pid");

        /* control methods are safe no-ops in the core (don't signal our own process) */
        CHECK(![cur hide] && ![cur unhide] && ![cur terminate] && ![cur forceTerminate]
              && ![cur activateWithOptions:0], "control methods stage2 no-ops");
        CHECK(!cur.isTerminated, "still not terminated after no-op terminate");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
