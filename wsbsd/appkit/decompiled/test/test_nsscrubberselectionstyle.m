/* test_nsscrubberselectionstyle.m — behaviour checks for NSScrubberSelectionStyle core */
#import "../src/NSScrubberSelectionStyle.h"
#import "../src/NSView.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface MySelView : NSView @end
@implementation MySelView @end

int main(void) {
    @autoreleasepool {
        /* built-in styles vend distinct objects */
        NSScrubberSelectionStyle *o = [NSScrubberSelectionStyle outlineOverlayStyle];
        NSScrubberSelectionStyle *n = [NSScrubberSelectionStyle nonHighlightingOutlineOverlayStyle];
        NSScrubberSelectionStyle *r = [NSScrubberSelectionStyle roundedBackgroundStyle];
        CHECK(o && n && r, "built-in styles vend objects");
        CHECK(o != n && o != r, "distinct style objects");

        /* built-in makeSelectionView is stage2 (nil) but safe */
        CHECK([o makeSelectionView] == nil, "built-in makeSelectionView stage2 nil");

        /* tinted rounded background variant */
        id tint = [NSObject new];
        NSScrubberSelectionStyle *rt = [NSScrubberSelectionStyle roundedBackgroundStyleWithTintColor:(id)tint];
        CHECK(rt != nil, "tinted rounded-background style");

        /* custom view class: makeSelectionView instantiates it 1:1 */
        NSScrubberSelectionStyle *custom = [NSScrubberSelectionStyle selectionStyleWithViewClass:[MySelView class]];
        NSView *v = [custom makeSelectionView];
        CHECK([v isKindOfClass:[MySelView class]], "custom style makeSelectionView instantiates the class");
        NSView *v2 = [custom makeSelectionView];
        CHECK(v2 != nil && v2 != v, "makeSelectionView returns a fresh view each call");

        /* conforms to NSCoding */
        CHECK([custom conformsToProtocol:@protocol(NSCoding)], "conforms to NSCoding");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
