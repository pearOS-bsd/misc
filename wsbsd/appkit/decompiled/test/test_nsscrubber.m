/* test_nsscrubber.m — behaviour checks for NSScrubber data/selection core */
#import "../src/NSScrubber.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface DS : NSObject <NSScrubberDataSource>
@property NSInteger count;
@end
@implementation DS
- (NSInteger)numberOfItemsForScrubber:(NSScrubber *)s { return _count; }
- (NSView *)scrubber:(NSScrubber *)s viewForItemAtIndex:(NSInteger)i { return [[NSView alloc] initWithFrame:NSZeroRect]; }
@end

@interface Del : NSObject <NSScrubberDelegate>
@property NSInteger lastSelected;
@end
@implementation Del
- (instancetype)init { if ((self=[super init])) _lastSelected = -2; return self; }
- (void)scrubber:(NSScrubber *)s didSelectItemAtIndex:(NSInteger)i { _lastSelected = i; }
@end

int main(void) {
    @autoreleasepool {
        NSScrubber *s = [[NSScrubber alloc] initWithFrame:NSMakeRect(0,0,200,30)];
        CHECK([s isKindOfClass:[NSView class]], "is an NSView");

        /* measured defaults */
        CHECK(s.selectedIndex == -1 && s.highlightedIndex == -1, "indices default -1");
        CHECK(s.numberOfItems == 0, "no items initially");
        CHECK(s.mode == NSScrubberModeFixed, "mode default Fixed");
        CHECK(s.itemAlignment == NSScrubberAlignmentNone, "itemAlignment default None");
        CHECK(!s.showsArrowButtons && !s.isContinuous && !s.floatsSelectionViews, "flags default NO");
        CHECK(NSScrubberModeFree==1 && NSScrubberAlignmentCenter==3, "enum values");

        /* dataSource drives numberOfItems via reloadData (setDataSource reloads) */
        DS *ds = [DS new]; ds.count = 5;
        s.dataSource = ds;
        CHECK(s.numberOfItems == 5, "numberOfItems from dataSource after set");
        ds.count = 3; [s reloadData];
        CHECK(s.numberOfItems == 3, "reloadData refreshes count");

        /* selection clamps to [-1, count-1] and fires delegate */
        Del *del = [Del new]; s.delegate = del;
        s.selectedIndex = 1;
        CHECK(s.selectedIndex == 1 && del.lastSelected == 1, "select index fires delegate");
        s.selectedIndex = 99;
        CHECK(s.selectedIndex == 2, "selectedIndex clamps to count-1");
        s.selectedIndex = -5;
        CHECK(s.selectedIndex == -1, "selectedIndex clamps to -1");

        /* shrinking data clamps an out-of-range selection */
        s.selectedIndex = 2;
        ds.count = 1; [s reloadData];
        CHECK(s.selectedIndex == 0, "reloadData clamps selection to new count");
        ds.count = 0; [s reloadData];
        CHECK(s.selectedIndex == -1, "empty data clears selection");

        /* itemViewForItemAtIndex vends from the data source */
        ds.count = 4; [s reloadData];
        CHECK([s itemViewForItemAtIndex:0] != nil, "itemView vended for valid index");
        CHECK([s itemViewForItemAtIndex:99] == nil, "itemView nil for out-of-range index");

        /* config setters */
        s.mode = NSScrubberModeFree; s.itemAlignment = NSScrubberAlignmentCenter;
        s.showsArrowButtons = YES; s.continuous = YES; s.floatsSelectionViews = YES; s.tag = 7;
        CHECK(s.mode == NSScrubberModeFree && s.itemAlignment == NSScrubberAlignmentCenter
              && s.showsArrowButtons && s.isContinuous && s.floatsSelectionViews && s.tag == 7, "config setters");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
