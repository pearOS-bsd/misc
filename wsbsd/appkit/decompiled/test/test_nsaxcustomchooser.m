/* test_nsaxcustomchooser.m */
#import "../src/NSAccessibilityCustomChooserSearchPredicate.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        /* item result */
        id el = [NSObject new];
        NSValue *rng = [NSValue valueWithRange:NSMakeRange(2, 3)];
        NSAccessibilityCustomChooserItemResult *r = [[NSAccessibilityCustomChooserItemResult alloc] initWithTargetElement:(id)el targetRange:rng];
        CHECK(r.targetElement == el, "targetElement stored (weak)");
        CHECK(r.targetRange == rng, "targetRange stored");
        CHECK(r.descriptionOverride == nil, "descriptionOverride nil default");
        r.descriptionOverride = @"Custom";
        CHECK([r.descriptionOverride isEqual:@"Custom"], "descriptionOverride set");

        /* search predicate */
        NSAccessibilityCustomChooserSearchPredicate *p = [[NSAccessibilityCustomChooserSearchPredicate alloc] init];
        CHECK(p.searchDirection == NSAccessibilityCustomChooserSearchDirectionPrevious, "searchDirection default Previous(0)");
        CHECK(NSAccessibilityCustomChooserSearchDirectionNext == 1, "direction enum");
        p.currentItem = r;
        CHECK(p.currentItem == r, "currentItem stored");
        p.searchDirection = NSAccessibilityCustomChooserSearchDirectionNext;
        CHECK(p.searchDirection == NSAccessibilityCustomChooserSearchDirectionNext, "searchDirection set");
        NSMutableString *f = [NSMutableString stringWithString:@"ab"];
        p.filterText = f; [f appendString:@"cd"];
        CHECK([p.filterText isEqual:@"ab"], "filterText snapshot-copied");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
