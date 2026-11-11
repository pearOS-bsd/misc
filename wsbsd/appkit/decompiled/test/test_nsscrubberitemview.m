/* test_nsscrubberitemview.m — behaviour checks for the NSScrubber view hierarchy */
#import "../src/NSScrubberItemView.h"
#import <math.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)
#define EQ(a,b) (fabs((a)-(b)) < 1e-6)

int main(void) {
    @autoreleasepool {
        /* hierarchy */
        NSScrubberArrangedView *av = [[NSScrubberArrangedView alloc] initWithFrame:NSZeroRect];
        CHECK([av isKindOfClass:[NSView class]], "arranged view is an NSView");
        NSScrubberItemView *iv = [[NSScrubberItemView alloc] initWithFrame:NSZeroRect];
        CHECK([iv isKindOfClass:[NSScrubberArrangedView class]], "item view : arranged view");
        NSScrubberSelectionView *sv = [[NSScrubberSelectionView alloc] initWithFrame:NSZeroRect];
        CHECK([sv isKindOfClass:[NSScrubberArrangedView class]], "selection view : arranged view");

        /* flag defaults + setters */
        CHECK(!av.isSelected && !av.isHighlighted, "flags default NO");
        av.selected = YES; av.highlighted = YES;
        CHECK(av.isSelected && av.isHighlighted, "flags set");

        /* applyLayoutAttributes sets the frame */
        NSScrubberLayoutAttributes *a = [NSScrubberLayoutAttributes layoutAttributesForItemAtIndex:0];
        a.frame = NSMakeRect(5, 0, 44, 30);
        [iv applyLayoutAttributes:a];
        CHECK(EQ(iv.frame.origin.x, 5) && EQ(iv.frame.size.width, 44) && EQ(iv.frame.size.height, 30),
              "applyLayoutAttributes sets the view frame");

        /* item view selection accessories */
        iv.selectionBackgroundView = sv;
        CHECK(iv.selectionBackgroundView == sv, "selectionBackgroundView stored");
        NSScrubberSelectionView *ov = [[NSScrubberSelectionView alloc] initWithFrame:NSZeroRect];
        iv.selectionOverlayView = ov;
        CHECK(iv.selectionOverlayView == ov, "selectionOverlayView stored");
        id layer = [NSObject new];
        iv.leftMaskLayer = layer;
        CHECK(iv.leftMaskLayer == layer, "leftMaskLayer stored");

        /* prepareForReuse resets selection/highlight */
        iv.selected = YES; iv.highlighted = YES;
        [iv prepareForReuse];
        CHECK(!iv.isSelected && !iv.isHighlighted, "prepareForReuse resets flags");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
