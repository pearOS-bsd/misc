/* test_nscustomtouchbaritem.m — NSCustomTouchBarItem view/viewController. */
#import "../src/NSCustomTouchBarItem.h"
#import "../src/NSViewController.h"
#import "../src/NSView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSCustomTouchBarItem *item = [[NSCustomTouchBarItem alloc] initWithIdentifier:@"custom"];
        CHECK([item isKindOfClass:[NSTouchBarItem class]], "is an NSTouchBarItem");
        CHECK([item.identifier isEqualToString:@"custom"], "identifier inherited");
        CHECK(item.view == nil, "no view initially");

        NSView *v = [[NSView alloc] initWithFrame:CGRectMake(0,0,80,30)];
        item.view = v;
        CHECK(item.view == v, "view set directly");
        CHECK(item.viewController == nil, "setting a view clears view controller");

        /* view controller provides the view */
        NSViewController *vc = [[NSViewController alloc] init];
        NSView *cv = [[NSView alloc] initWithFrame:CGRectMake(0,0,100,30)];
        vc.view = cv;
        item.viewController = vc;
        CHECK(item.viewController == vc, "view controller set");
        CHECK(item.view == cv, "item view comes from the view controller");

        item.customizationLabel = @"Play/Pause";
        CHECK([item.customizationLabel isEqualToString:@"Play/Pause"], "customization label set");

        /* visibility priority inherited from base */
        item.visibilityPriority = NSTouchBarItemPriorityHigh;
        CHECK(item.visibilityPriority == 1000, "inherited visibility priority works");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
