/* test_nsrulerview.m */
#import "../src/NSRulerView.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSRulerView *r = [[NSRulerView alloc] initWithScrollView:nil orientation:NSHorizontalRuler];
        CHECK([r isKindOfClass:[NSView class]], "is-a NSView");

        /* measured defaults */
        CHECK(r.orientation == NSHorizontalRuler, "orientation from init");
        CHECK(r.ruleThickness == 17.0, "ruleThickness 17 default");
        CHECK(r.reservedThicknessForMarkers == 15.0, "reservedThicknessForMarkers 15 default");
        CHECK(r.reservedThicknessForAccessoryView == 0.0, "reservedThicknessForAccessoryView 0 default");
        CHECK(r.originOffset == 0.0, "originOffset 0 default");
        CHECK(r.measurementUnits != nil, "measurementUnits non-nil default");
        CHECK(r.markers == nil, "markers nil default");

        /* requiredThickness = sum of the three reserved bands (measured 32) */
        CHECK(r.requiredThickness == 32.0, "requiredThickness = 17+15+0 = 32");

        /* enum */
        CHECK(NSHorizontalRuler == 0 && NSVerticalRuler == 1, "orientation enum");

        /* markers */
        id m1 = [NSObject new], m2 = [NSObject new];
        [r addMarker:(id)m1]; [r addMarker:(id)m2];
        CHECK(r.markers.count == 2, "two markers added");
        [r addMarker:(id)m1];
        CHECK(r.markers.count == 2, "duplicate marker deduped");
        [r removeMarker:(id)m1];
        CHECK(r.markers.count == 1 && r.markers[0] == m2, "marker removed");

        /* requiredThickness updates with reserved bands */
        r.reservedThicknessForAccessoryView = 10;
        CHECK(r.requiredThickness == 42.0, "requiredThickness tracks accessory band");

        /* setters */
        r.ruleThickness = 20; CHECK(r.ruleThickness == 20, "ruleThickness set");
        r.measurementUnits = @"Points"; CHECK([r.measurementUnits isEqual:@"Points"], "measurementUnits set");
        r.originOffset = 5; CHECK(r.originOffset == 5, "originOffset set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
