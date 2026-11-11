/* test_nsdraggingsession.m — behaviour checks for NSDraggingSession core */
#import "../src/NSDraggingSession.h"
#import "../src/NSDraggingItem.h"
#import "../src/NSPasteboard.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface NSDraggingSession (TestInternals)
- (instancetype)_initWithPasteboard:(NSPasteboard *)pb items:(NSArray *)items sequenceNumber:(NSInteger)n;
@end

int main(void) {
    @autoreleasepool {
        NSPasteboard *pb = [NSPasteboard pasteboardWithName:@"drag-test"];
        NSDraggingItem *i1 = [[NSDraggingItem alloc] initWithPasteboardWriter:@"a"];
        NSDraggingItem *i2 = [[NSDraggingItem alloc] initWithPasteboardWriter:@"b"];
        NSDraggingSession *s = [[NSDraggingSession alloc] _initWithPasteboard:pb items:@[i1, i2] sequenceNumber:42];

        /* identity */
        CHECK(s.draggingPasteboard == pb, "draggingPasteboard stored");
        CHECK(s.draggingSequenceNumber == 42, "draggingSequenceNumber stored");
        CHECK(s.numberOfDraggedItems == 2, "numberOfDraggedItems == item count");

        /* documented defaults */
        CHECK(s.draggingFormation == NSDraggingFormationDefault, "draggingFormation default Default(0)");
        CHECK(s.animatesToStartingPositionsOnCancelOrFail, "animatesToStartingPositionsOnCancelOrFail default YES");
        CHECK(s.draggingLeaderIndex == 0, "draggingLeaderIndex default 0");

        /* enum values */
        CHECK(NSDraggingFormationList == 4 && NSDraggingFormationPile == 2, "formation enum values");

        /* setters */
        s.draggingFormation = NSDraggingFormationStack;
        CHECK(s.draggingFormation == NSDraggingFormationStack, "draggingFormation set");
        s.animatesToStartingPositionsOnCancelOrFail = NO;
        CHECK(!s.animatesToStartingPositionsOnCancelOrFail, "animates flag set");
        s.draggingLeaderIndex = 1;
        CHECK(s.draggingLeaderIndex == 1, "draggingLeaderIndex set");
        s.draggingLocation = NSMakePoint(12, 34);
        CHECK(s.draggingLocation.x == 12 && s.draggingLocation.y == 34, "draggingLocation set");

        /* enumerate visits every item in order */
        __block NSInteger count = 0; __block BOOL ordered = YES;
        [s enumerateDraggingItemsWithOptions:0 forView:nil classes:@[] searchOptions:@{}
                                  usingBlock:^(NSDraggingItem *it, NSInteger idx, BOOL *stop) {
            if (idx == 0 && it != i1) ordered = NO;
            if (idx == 1 && it != i2) ordered = NO;
            count++;
        }];
        CHECK(count == 2 && ordered, "enumerate visits all items in order");

        /* stop halts enumeration */
        __block NSInteger visited = 0;
        [s enumerateDraggingItemsWithOptions:0 forView:nil classes:@[] searchOptions:@{}
                                  usingBlock:^(NSDraggingItem *it, NSInteger idx, BOOL *stop) {
            visited++; *stop = YES;
        }];
        CHECK(visited == 1, "stop halts enumeration");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
