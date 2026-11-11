/* test_nsaxcustomrotoritemresult.m */
#import "../src/NSAccessibilityCustomRotorItemResult.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* token + customLabel initializer */
        id<NSSecureCoding> tok = (id<NSSecureCoding>)@"token";
        NSAccessibilityCustomRotorItemResult *r = [[NSAccessibilityCustomRotorItemResult alloc] initWithItemLoadingToken:tok customLabel:@"Heading 1"];
        CHECK(r.itemLoadingToken == tok, "itemLoadingToken stored");
        CHECK([r.customLabel isEqual:@"Heading 1"], "customLabel stored");
        CHECK(r.targetElement == nil, "targetElement nil on token path");
        CHECK(r.targetRange.location == NSNotFound && r.targetRange.length == 0, "targetRange default {NSNotFound,0}");

        /* targetElement initializer */
        id el = [NSObject new];
        NSAccessibilityCustomRotorItemResult *r2 = [[NSAccessibilityCustomRotorItemResult alloc] initWithTargetElement:(id)el];
        CHECK(r2.targetElement == el, "targetElement stored (weak)");
        CHECK(r2.targetRange.location == NSNotFound, "targetRange default on element path");

        /* setters */
        r.targetRange = NSMakeRange(5, 10);
        CHECK(r.targetRange.location == 5 && r.targetRange.length == 10, "targetRange set");
        r.customLabel = @"Changed";
        CHECK([r.customLabel isEqual:@"Changed"], "customLabel set");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
