/* test_nsaxcustomrotorsearchparameters.m */
#import "../src/NSAccessibilityCustomRotorSearchParameters.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSAccessibilityCustomRotorSearchParameters *p = [[NSAccessibilityCustomRotorSearchParameters alloc] init];
        CHECK(p.currentItem == nil, "currentItem nil by default");
        CHECK(p.searchDirection == NSAccessibilityCustomRotorSearchDirectionPrevious, "searchDirection default Previous(0)");
        CHECK(NSAccessibilityCustomRotorSearchDirectionPrevious == 0 && NSAccessibilityCustomRotorSearchDirectionNext == 1, "direction enum");

        p.searchDirection = NSAccessibilityCustomRotorSearchDirectionNext;
        CHECK(p.searchDirection == NSAccessibilityCustomRotorSearchDirectionNext, "searchDirection set");

        /* filterString copies */
        NSMutableString *f = [NSMutableString stringWithString:@"foo"];
        p.filterString = f;
        [f appendString:@"bar"];
        CHECK([p.filterString isEqual:@"foo"], "filterString snapshot-copied");

        id item = [NSObject new];
        p.currentItem = (id)item;
        CHECK(p.currentItem == item, "currentItem stored");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
