/* test_nsdocktile.m — NSDockTile value fields. */
#import "../src/NSDockTile.h"
#import "../src/NSView.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSDockTile *tile = [[NSDockTile alloc] init];
        CHECK(tile.badgeLabel == nil, "no badge by default");
        CHECK(!tile.showsApplicationBadge, "app badge off by default");
        CHECK(tile.size.width == 128 && tile.size.height == 128, "default tile size 128x128");
        CHECK(tile.contentView == nil, "no content view by default");

        tile.badgeLabel = @"42";
        CHECK([tile.badgeLabel isEqualToString:@"42"], "badge label set");
        tile.showsApplicationBadge = YES;
        CHECK(tile.showsApplicationBadge, "app badge flag set");

        NSView *cv = [[NSView alloc] initWithFrame:CGRectMake(0,0,128,128)];
        tile.contentView = cv;
        CHECK(tile.contentView == cv, "content view set");

        /* display is a no-op in the core, must not crash */
        [tile display];
        CHECK(1, "display does not crash");

        /* clearing the badge */
        tile.badgeLabel = nil;
        CHECK(tile.badgeLabel == nil, "badge label cleared");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
