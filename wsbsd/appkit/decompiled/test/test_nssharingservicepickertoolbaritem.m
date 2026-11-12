/* test_nssharingservicepickertoolbaritem.m */
#import "../src/NSSharingServicePickerToolbarItem.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface Src : NSObject <NSSharingServicePickerToolbarItemDelegate>
@property (copy) NSArray *items;
@property NSInteger asks;
@end
@implementation Src
- (NSArray *)itemsForSharingServicePickerToolbarItem:(NSSharingServicePickerToolbarItem *)i { self.asks++; return self.items; }
@end

@interface NSSharingServicePickerToolbarItem (Testing)
- (void)_pickerDidClose;
@end

int main(void) {
    @autoreleasepool {
        NSSharingServicePickerToolbarItem *it = [[NSSharingServicePickerToolbarItem alloc] initWithItemIdentifier:@"share"];
        CHECK([it isKindOfClass:[NSToolbarItem class]], "is NSToolbarItem");
        CHECK([it.itemIdentifier isEqual:@"share"], "identifier carried");
        CHECK(it.delegate == nil && !it.isShowing, "delegate nil, not showing default");

        Src *src = [Src new];
        it.delegate = src;
        CHECK(it.delegate == src, "delegate set");

        /* no items => share is a no-op, picker not shown */
        src.items = @[];
        [it share:nil];
        CHECK(src.asks == 1 && !it.isShowing, "empty items: asked once, not showing");

        /* with items => picker shows, delegate asked */
        src.items = @[@"doc1", @"doc2"];
        [it share:nil];
        CHECK(src.asks == 2 && it.isShowing, "items present: showing");

        /* already showing => share re-entrancy ignored, delegate not re-asked */
        [it share:nil];
        CHECK(src.asks == 2 && it.isShowing, "re-entrant share ignored");

        /* dismissing clears showing */
        [it _pickerDidClose];
        CHECK(!it.isShowing, "dismiss clears showing");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
