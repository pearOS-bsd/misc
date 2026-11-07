/*
 * test_nswindow.m — NSWindow data + responder core: init, title, styleMask,
 * contentView, delegate (weak), visibility, and makeFirstResponder:.
 */
#import "../src/NSWindow.h"

/* a responder that accepts first-responder status, to drive makeFirstResponder: */
@interface KeyView : NSView
@property (nonatomic) BOOL becameFirst;
@property (nonatomic) BOOL resigned;
@end
@implementation KeyView
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)becomeFirstResponder { self.becameFirst = YES; return YES; }
- (BOOL)resignFirstResponder { self.resigned = YES; return YES; }
@end

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        NSWindow *w = [[NSWindow alloc] initWithContentRect:CGRectMake(0, 0, 400, 300)
                                                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];

        CHECK(w.styleMask == (NSWindowStyleMaskTitled | NSWindowStyleMaskClosable), "styleMask stored");
        CHECK([w.title isEqualToString:@""], "title empty by default");
        w.title = @"Main";
        CHECK([w.title isEqualToString:@"Main"], "title round-trips");

        /* content view created, sized to content rect */
        CHECK(w.contentView != nil, "content view created");
        CHECK(CGRectEqualToRect(w.contentView.bounds, CGRectMake(0, 0, 400, 300)),
              "content view sized to content rect");

        /* delegate weak */
        id del = [NSObject new];
        w.delegate = del;
        CHECK(w.delegate == del, "delegate round-trips");

        /* visibility */
        CHECK(w.isVisible == NO, "window not visible before ordering front");
        [w makeKeyAndOrderFront:nil];
        CHECK(w.isVisible == YES, "visible after makeKeyAndOrderFront:");
        [w orderOut:nil];
        CHECK(w.isVisible == NO, "hidden after orderOut:");

        /* first responder defaults to the window */
        CHECK(w.firstResponder == w, "window is its own first responder initially");

        /* makeFirstResponder: a view that accepts */
        KeyView *kv = [[KeyView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        [w.contentView addSubview:kv];
        BOOL ok = [w makeFirstResponder:kv];
        CHECK(ok && w.firstResponder == kv, "makeFirstResponder sets the new responder");
        CHECK(kv.becameFirst, "new responder got becomeFirstResponder");

        /* switching away resigns the old one */
        KeyView *kv2 = [[KeyView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
        [w.contentView addSubview:kv2];
        [w makeFirstResponder:kv2];
        CHECK(kv.resigned, "old responder got resignFirstResponder");
        CHECK(w.firstResponder == kv2, "first responder switched");

        /* clearing -> window becomes first responder */
        [w makeFirstResponder:nil];
        CHECK(w.firstResponder == w, "nil first responder falls back to the window");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
