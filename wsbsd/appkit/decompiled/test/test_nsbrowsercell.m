/* test_nsbrowsercell.m */
#import "../src/NSBrowserCell.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSBrowserCell *c = [[NSBrowserCell alloc] initTextCell:@"Item"];
        CHECK([c isKindOfClass:[NSCell class]], "is-a NSCell");

        /* measured defaults */
        CHECK(!c.isLeaf, "not leaf default");
        CHECK(c.isLoaded, "loaded YES after initTextCell (measured)");
        CHECK([c.stringValue isEqual:@"Item"], "title stored");
        CHECK(c.image == nil && c.alternateImage == nil, "no images default");

        /* branch images are stage2 (nil here) */
        CHECK([NSBrowserCell branchImage] == nil, "branchImage stage2 nil");
        CHECK([NSBrowserCell highlightedBranchImage] == nil, "highlightedBranchImage stage2 nil");

        /* set / reset toggle highlight + state */
        [c set];
        CHECK(c.isHighlighted && c.state == 1, "set highlights");
        [c reset];
        CHECK(!c.isHighlighted && c.state == 0, "reset clears");

        /* setters */
        c.leaf = YES; CHECK(c.isLeaf, "leaf set");
        c.loaded = NO; CHECK(!c.isLoaded, "loaded set");
        id img = [NSObject new]; c.image = (id)img; CHECK((id)c.image == img, "image set");
        c.stringValue = @"Other"; CHECK([c.stringValue isEqual:@"Other"], "stringValue set");

        /* image init variant */
        NSBrowserCell *ci = [[NSBrowserCell alloc] initImageCell:(id)img];
        CHECK((id)ci.image == img && ci.isLoaded, "initImageCell stores image + loaded");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
