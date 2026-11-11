/* test_nsaxcustomrotor.m */
#import "../src/NSAccessibilityCustomRotor.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        id del = [NSObject new];

        /* label initializer -> Custom type */
        NSAccessibilityCustomRotor *r = [[NSAccessibilityCustomRotor alloc] initWithLabel:@"Bookmarks" itemSearchDelegate:(id)del];
        CHECK([r.label isEqual:@"Bookmarks"], "label stored");
        CHECK(r.type == NSAccessibilityCustomRotorTypeCustom, "label init -> Custom type");
        CHECK(r.itemSearchDelegate == del, "search delegate stored (weak)");

        /* type initializer -> empty label */
        NSAccessibilityCustomRotor *r2 = [[NSAccessibilityCustomRotor alloc] initWithRotorType:NSAccessibilityCustomRotorTypeHeading itemSearchDelegate:nil];
        CHECK(r2.type == NSAccessibilityCustomRotorTypeHeading, "type init stores type");
        CHECK([r2.label isEqual:@""], "type init -> empty label");

        /* enum values */
        CHECK(NSAccessibilityCustomRotorTypeCustom == 0 && NSAccessibilityCustomRotorTypeAny == 1
              && NSAccessibilityCustomRotorTypeHeading == 4, "rotor-type enum values");

        /* setters */
        r.type = NSAccessibilityCustomRotorTypeLink;
        CHECK(r.type == NSAccessibilityCustomRotorTypeLink, "type set");
        NSMutableString *l = [NSMutableString stringWithString:@"X"];
        r.label = l; [l appendString:@"Y"];
        CHECK([r.label isEqual:@"X"], "label snapshot-copied");
        id ld = [NSObject new];
        r.itemLoadingDelegate = (id)ld;
        CHECK(r.itemLoadingDelegate == ld, "loading delegate stored");

        /* nil label coerces to empty */
        NSString *nilStr = nil;
        r.label = nilStr;
        CHECK([r.label isEqual:@""], "nil label -> empty");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
