/* test_nspickertouchbaritem.m */
#import "../src/NSPickerTouchBarItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSPickerTouchBarItem *p = [NSPickerTouchBarItem pickerTouchBarItemWithIdentifier:@"id"
            labels:@[@"A", @"B", @"C"] selectionMode:NSPickerTouchBarItemSelectionModeSelectOne target:nil action:NULL];
        CHECK([p isKindOfClass:[NSTouchBarItem class]], "is NSTouchBarItem");

        /* measured: factory sizes options, default selection/mode/rep */
        CHECK(p.numberOfOptions == 3, "3 options from labels");
        CHECK(p.selectedIndex == -1, "selectedIndex default -1");
        CHECK(p.selectionMode == NSPickerTouchBarItemSelectionModeSelectOne, "selectionMode SelectOne");
        CHECK(p.controlRepresentation == NSPickerTouchBarItemControlRepresentationAutomatic, "ctrlRep Automatic");
        CHECK(p.isEnabled, "item enabled default YES");
        CHECK([[p labelAtIndex:1] isEqual:@"B"], "labelAtIndex:1 == B");
        CHECK([p isEnabledAtIndex:0], "options enabled by default");

        /* enum values */
        CHECK(NSPickerTouchBarItemSelectionModeSelectAny == 1 && NSPickerTouchBarItemSelectionModeMomentary == 2, "selection-mode enum");
        CHECK(NSPickerTouchBarItemControlRepresentationCollapsed == 2, "control-rep enum");

        /* selectedIndex clamps to valid range */
        p.selectedIndex = 2; CHECK(p.selectedIndex == 2, "select valid index");
        p.selectedIndex = 9; CHECK(p.selectedIndex == -1, "out-of-range -> -1");

        /* per-option mutation */
        [p setLabel:@"BB" atIndex:1];
        CHECK([[p labelAtIndex:1] isEqual:@"BB"], "setLabel:atIndex:");
        [p setEnabled:NO atIndex:0];
        CHECK(![p isEnabledAtIndex:0], "setEnabled:NO atIndex:0");
        id img = [NSObject new];
        [p setImage:(id)img atIndex:2];
        CHECK([p imageAtIndex:2] == img, "setImage:atIndex:");

        /* grow/shrink numberOfOptions */
        [p setNumberOfOptions:5];
        CHECK(p.numberOfOptions == 5 && [p labelAtIndex:4] == nil, "grow adds empty options");
        [p setNumberOfOptions:1];
        CHECK(p.numberOfOptions == 1, "shrink drops options");

        /* bare init: 0 options */
        NSPickerTouchBarItem *d = [[NSPickerTouchBarItem alloc] initWithIdentifier:@"d"];
        CHECK(d.numberOfOptions == 0 && d.selectedIndex == -1, "bare init empty");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
