/* test_nsrulermarker.m — NSRulerMarker value object. */
#import "../src/NSRulerMarker.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        id ruler = [NSObject new];
        id img = [NSObject new];
        NSRulerMarker *m = [[NSRulerMarker alloc] initWithRulerView:ruler
                                                     markerLocation:72.0
                                                              image:img
                                                        imageOrigin:CGPointMake(0, 4)];
        CHECK(m.ruler == ruler, "ruler from init");
        CHECK(m.markerLocation == 72.0, "location from init");
        CHECK(m.image == img, "image from init");
        CHECK(m.imageOrigin.y == 4, "image origin from init");
        CHECK(m.isMovable, "movable by default");
        CHECK(m.isRemovable, "removable by default");

        m.markerLocation = 144.0;
        m.movable = NO;
        m.removable = NO;
        id rep = [NSObject new];
        m.representedObject = rep;
        CHECK(m.markerLocation == 144.0, "location set");
        CHECK(!m.isMovable && !m.isRemovable, "flags cleared");
        CHECK(m.representedObject == rep, "represented object set");

        /* copy keeps values */
        NSRulerMarker *c = [m copy];
        CHECK(c.markerLocation == 144.0 && !c.isMovable && c.representedObject == rep, "copy carries values");
        c.markerLocation = 0;
        CHECK(m.markerLocation == 144.0, "copy independent");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
