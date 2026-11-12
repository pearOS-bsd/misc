/* test_nswindowtabgroup.m */
#import "../src/NSWindowTabGroup.h"
#import "../src/NSWindow.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

static NSWindow *mkwin(void) {
    return [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,100,100) styleMask:0 backing:2 defer:YES];
}

int main(void) {
    @autoreleasepool {
        NSWindowTabGroup *g = [[NSWindowTabGroup alloc] initWithTabbingIdentifier:@"docs"];
        CHECK([g.identifier isEqual:@"docs"], "identifier from init");
        CHECK(g.windows.count == 0 && g.selectedWindow == nil, "empty group");
        CHECK(g.allowsDraggingTabs && g.allowsDetachingTabs, "drag/detach default YES");
        CHECK(g.isTabBarEnabled, "tabBarEnabled default YES");
        CHECK(!g.isTabBarVisible, "tab bar not visible when empty");

        NSWindow *w1 = mkwin(), *w2 = mkwin(), *w3 = mkwin();
        [g addWindow:w1];
        CHECK(g.windows.count == 1 && g.selectedWindow == w1, "first window added + auto-selected");
        CHECK(!g.isTabBarVisible, "one window: tab bar hidden");
        g.shouldShowTabBarWithOneItem = YES;
        CHECK(g.isTabBarVisible, "shouldShowTabBarWithOneItem -> visible with one");

        [g addWindow:w2];
        CHECK(g.windows.count == 2 && g.isTabBarVisible, "two windows: tab bar visible");
        [g insertWindow:w3 atIndex:1];
        CHECK(g.windows.count == 3 && g.windows[1] == w3, "insert at index");
        [g addWindow:w1];  /* dup ignored */
        CHECK(g.windows.count == 3, "duplicate add ignored");

        /* selection + removal */
        g.selectedWindow = w3;
        CHECK(g.selectedWindow == w3, "select a member");
        [g removeWindow:w3];
        CHECK(g.windows.count == 2 && g.selectedWindow != w3 && g.selectedWindow != nil, "removing selected picks a neighbour");
        [g removeWindow:w1]; [g removeWindow:w2];
        CHECK(g.windows.count == 0 && g.selectedWindow == nil, "emptying clears selection");

        /* setting a non-member selection is ignored */
        NSWindow *stray = mkwin();
        g.selectedWindow = stray;
        CHECK(g.selectedWindow == nil, "non-member selection ignored");

        /* tabBarEnabled gates visibility */
        [g addWindow:w1]; [g addWindow:w2];
        g.tabBarEnabled = NO;
        CHECK(!g.isTabBarVisible, "disabled tab bar never visible");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
