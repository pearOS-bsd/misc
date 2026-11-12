/* test_nspopovertouchbaritem.m */
#import "../src/NSPopoverTouchBarItem.h"
#import "../src/NSTouchBar.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSPopoverTouchBarItem *p = [[NSPopoverTouchBarItem alloc] initWithIdentifier:@"pop"];
        CHECK([p isKindOfClass:[NSTouchBarItem class]], "is NSTouchBarItem");
        CHECK([p.identifier isEqual:@"pop"], "identifier carried");

        /* measured defaults */
        CHECK(!p.isPresented, "not presented default");
        CHECK(p.showsCloseButton, "showsCloseButton YES default");
        CHECK(!p.collapsedRepresentationShowsChevron, "chevron NO default");
        CHECK([p.customizationLabel isEqual:@""], "customizationLabel empty default");
        CHECK(p.pressAndHoldTouchBar == nil, "pressAndHoldTouchBar nil default");
        CHECK(p.collapsedRepresentationImage == nil && p.collapsedRepresentationLabel == nil, "collapsed image/label nil default");

        /* popoverTouchBar is lazily auto-created (non-nil) and stable */
        NSTouchBar *bar = p.popoverTouchBar;
        CHECK(bar != nil, "popoverTouchBar auto-created non-nil");
        CHECK(p.popoverTouchBar == bar, "popoverTouchBar stable across reads");

        /* null_resettable: setting nil re-arms the lazy getter with a fresh bar */
        p.popoverTouchBar = nil;
        NSTouchBar *bar2 = p.popoverTouchBar;
        CHECK(bar2 != nil && bar2 != bar, "nil reset re-creates popoverTouchBar");

        /* setters */
        NSTouchBar *ph = [[NSTouchBar alloc] init];
        p.pressAndHoldTouchBar = ph;
        CHECK(p.pressAndHoldTouchBar == ph, "pressAndHoldTouchBar set");
        p.customizationLabel = @"More";
        CHECK([p.customizationLabel isEqual:@"More"], "customizationLabel set");
        p.collapsedRepresentationLabel = @"Tools";
        CHECK([p.collapsedRepresentationLabel isEqual:@"Tools"], "collapsedRepresentationLabel set");
        id img = [NSObject new]; p.collapsedRepresentationImage = (id)img;
        CHECK((id)p.collapsedRepresentationImage == img, "collapsedRepresentationImage set");
        id view = [NSObject new]; p.collapsedRepresentation = (id)view;
        CHECK((id)p.collapsedRepresentation == view, "collapsedRepresentation set");
        p.collapsedRepresentationShowsChevron = YES;
        CHECK(p.collapsedRepresentationShowsChevron, "chevron set");
        p.showsCloseButton = NO;
        CHECK(!p.showsCloseButton, "showsCloseButton set");

        /* presentation toggling */
        [p showPopover:nil];
        CHECK(p.isPresented, "showPopover presents");
        [p dismissPopover:nil];
        CHECK(!p.isPresented, "dismissPopover hides");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
