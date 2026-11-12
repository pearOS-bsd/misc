/* test_nsaccessibilityelement.m */
#import "../src/NSAccessibilityElement.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* plain init */
        NSAccessibilityElement *p = [[NSAccessibilityElement alloc] init];
        CHECK(p.isAccessibilityElement, "isAccessibilityElement YES default");
        CHECK(p.accessibilityRole == nil, "role nil default");
        CHECK(CGRectEqualToRect(p.accessibilityFrameInParentSpace, CGRectZero), "frameInParentSpace zero default");
        CHECK(p.accessibilityChildren == nil, "children nil when empty");

        /* factory stores role/frame/label and parent link, no auto-add */
        NSAccessibilityElement *parent = [NSAccessibilityElement accessibilityElementWithRole:@"AXGroup" frame:CGRectZero label:@"p" parent:nil];
        NSAccessibilityElement *e = [NSAccessibilityElement accessibilityElementWithRole:@"AXButton"
                                                                                  frame:CGRectMake(1,2,3,4)
                                                                                  label:@"OK"
                                                                                 parent:parent];
        CHECK([e.accessibilityRole isEqual:@"AXButton"], "factory role");
        CHECK([e.accessibilityLabel isEqual:@"OK"], "factory label");
        CHECK(CGRectEqualToRect(e.accessibilityFrame, CGRectMake(1,2,3,4)), "factory frame");
        CHECK(e.isAccessibilityElement, "factory isAccessibilityElement YES");
        CHECK(e.accessibilityParent == parent, "factory sets parent link");
        CHECK(parent.accessibilityChildren == nil, "factory does NOT add to parent children");

        /* addChildElement appends + re-parents */
        NSAccessibilityElement *c1 = [[NSAccessibilityElement alloc] init];
        [parent accessibilityAddChildElement:c1];
        CHECK(parent.accessibilityChildren.count == 1 && parent.accessibilityChildren[0] == c1, "child appended");
        CHECK(c1.accessibilityParent == parent, "child re-parented to receiver");

        /* adding the same child twice is deduped */
        [parent accessibilityAddChildElement:c1];
        CHECK(parent.accessibilityChildren.count == 1, "duplicate child add deduped");

        /* adding e (created with parent:parent) actually lists it now */
        [parent accessibilityAddChildElement:e];
        CHECK(parent.accessibilityChildren.count == 2, "second distinct child appended");

        /* setters */
        e.accessibilityValue = @(42);
        CHECK([e.accessibilityValue isEqual:@(42)], "value set");
        e.accessibilityIdentifier = @"btn.ok";
        CHECK([e.accessibilityIdentifier isEqual:@"btn.ok"], "identifier set");
        e.accessibilityFrameInParentSpace = CGRectMake(5,6,7,8);
        CHECK(e.accessibilityFrameInParentSpace.size.width == 7, "frameInParentSpace set");
        e.accessibilityElement = NO;
        CHECK(!e.isAccessibilityElement, "isAccessibilityElement settable");
        e.accessibilityEnabled = YES; e.accessibilityFocused = YES;
        CHECK(e.isAccessibilityEnabled && e.isAccessibilityFocused, "enabled/focused set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
