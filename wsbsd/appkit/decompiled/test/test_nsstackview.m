/* test_nsstackview.m — NSStackView: orientation, spacing, arranged subviews. */
#import "../src/NSStackView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSStackView *sv = [[NSStackView alloc] initWithFrame:CGRectMake(0, 0, 300, 50)];
        CHECK(sv.orientation == NSUserInterfaceLayoutOrientationHorizontal, "default horizontal");
        sv.orientation = NSUserInterfaceLayoutOrientationVertical;
        CHECK(sv.orientation == NSUserInterfaceLayoutOrientationVertical, "orientation round-trips");

        sv.spacing = 12.0;
        CHECK(sv.spacing == 12.0, "spacing round-trips");

        CHECK(sv.arrangedSubviews.count == 0, "no arranged subviews to start");
        NSView *a = [[NSView alloc] initWithFrame:CGRectMake(0,0,10,10)];
        NSView *b = [[NSView alloc] initWithFrame:CGRectMake(0,0,10,10)];
        [sv addArrangedSubview:a];
        [sv addArrangedSubview:b];
        CHECK(sv.arrangedSubviews.count == 2, "two arranged subviews");
        CHECK(a.superview == sv, "arranged subview is also a real subview");
        CHECK(sv.arrangedSubviews[0] == a && sv.arrangedSubviews[1] == b, "arranged order preserved");

        /* adding the same view twice is a no-op */
        [sv addArrangedSubview:a];
        CHECK(sv.arrangedSubviews.count == 2, "duplicate add ignored");

        /* removeArrangedSubview drops it from the arranged list but keeps it a subview */
        [sv removeArrangedSubview:a];
        CHECK(sv.arrangedSubviews.count == 1, "removed from arranged list");
        CHECK(a.superview == sv, "still a subview after removeArrangedSubview");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
