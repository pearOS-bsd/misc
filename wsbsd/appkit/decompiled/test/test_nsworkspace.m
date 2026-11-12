/* test_nsworkspace.m */
#import "../src/NSWorkspace.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSWorkspace *w = [NSWorkspace sharedWorkspace];
        CHECK(w != nil && w == [NSWorkspace sharedWorkspace], "sharedWorkspace singleton");

        /* notification center is dedicated, not the default one (measured) */
        CHECK(w.notificationCenter != nil, "notificationCenter non-nil");
        CHECK(w.notificationCenter != [NSNotificationCenter defaultCenter], "notificationCenter is NOT the default center");
        CHECK(w.notificationCenter == w.notificationCenter, "notificationCenter stable");

        /* stage2 actions return NO / nil / empty, must not crash */
        CHECK(![w openURL:[NSURL fileURLWithPath:@"/tmp/x"]], "openURL stage2 -> NO");
        CHECK(![w openFile:@"/tmp/x"], "openFile stage2 -> NO");
        CHECK(![w launchApplication:@"Foo"], "launchApplication stage2 -> NO");
        CHECK(![w selectFile:@"/tmp/x" inFileViewerRootedAtPath:@"/tmp"], "selectFile stage2 -> NO");
        CHECK([w iconForFile:@"/tmp/x"] == nil, "iconForFile stage2 -> nil");
        CHECK([w fullPathForApplication:@"Foo"] == nil, "fullPathForApplication stage2 -> nil");
        CHECK([w URLForApplicationToOpenURL:[NSURL fileURLWithPath:@"/tmp/x"]] == nil, "URLForApplicationToOpenURL stage2 -> nil");
        CHECK(w.runningApplications.count == 0, "runningApplications stage2 -> empty");

        /* the dedicated center actually works for post/observe */
        __block int hits = 0;
        id obs = [w.notificationCenter addObserverForName:@"T" object:nil queue:nil usingBlock:^(NSNotification *n){ hits++; }];
        [w.notificationCenter postNotificationName:@"T" object:nil];
        CHECK(hits == 1, "dedicated notification center delivers");
        [w.notificationCenter removeObserver:obs];
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
