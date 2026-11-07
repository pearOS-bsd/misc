/*
 * test_nsview.m — behaviour tests for the 1:1 NSView structural core.
 * Geometry, isFlipped, hierarchy (super/sub/window), isDescendantOf:, hitTest:.
 */
#import "../src/NSView.h"

/* Re-declare the internal window setter so the test can drive propagation. */
@interface NSView (TestInternal)
- (void)_setWindow:(id)w;
@end

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { \
    gChecks++; \
    if (!(cond)) { gFails++; fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } \
} while (0)

int main(void)
{
    @autoreleasepool {
        /* --- init: frame, bounds, isFlipped --- */
        NSView *v = [[NSView alloc] initWithFrame:CGRectMake(5, 6, 100, 80)];
        CHECK(CGRectEqualToRect(v.frame, CGRectMake(5, 6, 100, 80)), "initWithFrame sets frame");
        CHECK(CGRectEqualToRect(v.bounds, CGRectMake(0, 0, 100, 80)),
              "bounds starts at origin 0 with frame size");
        CHECK(v.isFlipped == NO, "isFlipped defaults NO");

        /* --- setFrame: --- */
        v.frame = CGRectMake(1, 2, 50, 50);
        CHECK(CGRectEqualToRect(v.frame, CGRectMake(1, 2, 50, 50)), "setFrame updates frame");

        /* --- hierarchy --- */
        NSView *parent = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        NSView *child  = [[NSView alloc] initWithFrame:CGRectMake(10, 10, 30, 30)];
        CHECK(parent.subviews.count == 0, "fresh view has no subviews");
        [parent addSubview:child];
        CHECK(child.superview == parent, "addSubview sets child.superview");
        CHECK(parent.subviews.count == 1 && parent.subviews[0] == child,
              "addSubview adds to subviews");

        /* subviews returns a copy, not internal storage */
        NSArray *s1 = parent.subviews;
        NSArray *s2 = parent.subviews;
        CHECK(s1 != s2, "subviews returns a fresh copy each call");

        /* --- window propagation --- */
        id win = [NSObject new];
        [parent _setWindow:win];
        CHECK(parent.window == win, "window set on parent");
        CHECK(child.window == win, "window propagates to subview");

        /* --- isDescendantOf: --- */
        NSView *grand = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 5, 5)];
        [child addSubview:grand];
        CHECK([grand isDescendantOf:parent] == YES, "grandchild is descendant of parent");
        CHECK([parent isDescendantOf:grand] == NO, "parent is not descendant of grandchild");
        CHECK([parent isDescendantOf:parent] == YES, "view is descendant of itself");

        /* --- removeFromSuperview --- */
        [child removeFromSuperview];
        CHECK(child.superview == nil, "removeFromSuperview clears superview");
        CHECK(parent.subviews.count == 0, "removeFromSuperview drops from parent");
        CHECK(child.window == nil, "removeFromSuperview clears the window chain");

        /* --- hitTest: --- */
        NSView *root = [[NSView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        NSView *box  = [[NSView alloc] initWithFrame:CGRectMake(10, 10, 30, 30)];
        [root addSubview:box];
        CHECK([root hitTest:CGPointMake(20, 20)] == box, "hitTest returns the deepest subview hit");
        CHECK([root hitTest:CGPointMake(5, 5)] == root, "hitTest returns self when only self is hit");
        CHECK([root hitTest:CGPointMake(200, 200)] == nil, "hitTest returns nil outside bounds");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
