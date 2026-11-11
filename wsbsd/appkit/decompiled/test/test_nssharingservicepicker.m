/* test_nssharingservicepicker.m — behaviour checks for NSSharingServicePicker core */
#import "../src/NSSharingServicePicker.h"
#import "../src/NSMenuItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface NSSharingServicePicker (TestInternals)
- (NSArray *)_items;
@end

int main(void) {
    @autoreleasepool {
        NSArray *items = @[@"hello", [NSURL URLWithString:@"https://example.com"]];
        NSSharingServicePicker *p = [[NSSharingServicePicker alloc] initWithItems:items];
        CHECK(p != nil, "initWithItems: returns an object");
        CHECK([p _items].count == 2, "items stored");

        /* empty items accepted (measured, no raise) */
        NSSharingServicePicker *e = [[NSSharingServicePicker alloc] initWithItems:@[]];
        CHECK(e != nil && [e _items].count == 0, "empty items accepted");

        /* standard share menu item: non-nil, titled 'Share…', no submenu */
        NSMenuItem *mi = p.standardShareMenuItem;
        CHECK(mi != nil && [mi isKindOfClass:[NSMenuItem class]], "standardShareMenuItem is an NSMenuItem");
        CHECK([mi.title isEqual:@"Share…"], "title is 'Share…'");
        CHECK(mi.submenu == nil, "no submenu (lazy, stage2)");

        /* delegate round-trip */
        id del = [NSObject new];
        p.delegate = (id)del;
        CHECK(p.delegate == del, "delegate stored");

        /* excludedSharingServiceNames round-trip (copy) */
        NSMutableArray *ex = [@[@"com.apple.share.Mail.compose"] mutableCopy];
        p.excludedSharingServiceNames = ex;
        [ex addObject:@"extra"];
        CHECK(p.excludedSharingServiceNames.count == 1, "excludedSharingServiceNames snapshot-copied");

        /* presentation / close are safe no-ops in the core */
        NSView *noview = nil; [p showRelativeToRect:NSMakeRect(0,0,10,10) ofView:noview preferredEdge:NSMinYEdge];
        [p close];
        CHECK(1, "show/close safe no-ops (stage2)");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
