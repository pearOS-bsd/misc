/* test — NSCollectionViewLayoutAttributes frame/center/size consistency. */
#import "../src/NSCollectionViewLayoutAttributes.h"
#import <math.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)
#define CLOSE(a,b) (fabs((a)-(b)) < 1e-9)

int main(void)
{
    @autoreleasepool {
        NSIndexPath *ip = [[NSIndexPath indexPathWithIndex:0] indexPathByAddingIndex:3];
        NSCollectionViewLayoutAttributes *a = [NSCollectionViewLayoutAttributes layoutAttributesForItemWithIndexPath:ip];
        CHECK(a.indexPath == ip, "index path from factory");
        CHECK(a.alpha == 1.0, "default alpha 1");
        CHECK(a.zIndex == 0, "default zIndex 0");
        CHECK(!a.isHidden, "not hidden by default");

        a.frame = CGRectMake(10, 20, 100, 40);
        CHECK(CLOSE(a.center.x, 60) && CLOSE(a.center.y, 40), "center derived from frame");
        CHECK(CLOSE(a.bounds.size.width, 100) && a.bounds.origin.x == 0, "bounds is {0,0,size}");
        CHECK(CLOSE(a.size.width, 100) && CLOSE(a.size.height, 40), "size from frame");

        /* setCenter moves the frame, keeps size */
        a.center = CGPointMake(200, 200);
        CHECK(CLOSE(a.frame.origin.x, 150) && CLOSE(a.frame.origin.y, 180), "setCenter moves frame");
        CHECK(CLOSE(a.frame.size.width, 100), "size unchanged by setCenter");

        /* setSize keeps center */
        CGPoint before = a.center;
        a.size = CGSizeMake(50, 50);
        CHECK(CLOSE(a.center.x, before.x) && CLOSE(a.center.y, before.y), "setSize keeps center");
        CHECK(CLOSE(a.frame.size.width, 50), "frame resized");

        /* setBounds resizes keeping center */
        before = a.center;
        a.bounds = CGRectMake(0, 0, 20, 20);
        CHECK(CLOSE(a.size.width, 20), "setBounds sets size");
        CHECK(CLOSE(a.center.x, before.x), "setBounds keeps center");

        a.alpha = 0.5; a.zIndex = 7; a.hidden = YES; a.floating = YES;
        CHECK(a.alpha == 0.5 && a.zIndex == 7 && a.isHidden && a.isFloating, "scalar props set");

        /* copy is independent */
        NSCollectionViewLayoutAttributes *b = [a copy];
        b.alpha = 0.1;
        CHECK(a.alpha == 0.5, "copy independent");
        CHECK(b.zIndex == 7, "copy carries values");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
