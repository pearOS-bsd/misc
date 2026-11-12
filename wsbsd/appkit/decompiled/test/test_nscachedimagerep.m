/* test_nscachedimagerep.m */
#import "../src/NSCachedImageRep.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

int main(void) {
    @autoreleasepool {
        NSCachedImageRep *r = [[NSCachedImageRep alloc] initWithSize:NSMakeSize(10,20) depth:0 separate:NO alpha:YES];
        CHECK([r isKindOfClass:[NSImageRep class]], "is-a NSImageRep");
        CHECK(r.size.width == 10 && r.size.height == 20, "size stored");
        CHECK(CGRectEqualToRect(r.rect, CGRectMake(0,0,10,20)), "rect = {0,0,size} (measured)");
        CHECK(r.window == nil, "no backing window in size init (window server = stage2)");

        /* window+rect init */
        id win = [NSObject new];
        NSCachedImageRep *r2 = [[NSCachedImageRep alloc] initWithWindow:(id)win rect:NSMakeRect(5,5,30,40)];
        CHECK((id)r2.window == win, "window stored");
        CHECK(CGRectEqualToRect(r2.rect, CGRectMake(5,5,30,40)), "rect stored");
        CHECK(r2.size.width == 30 && r2.size.height == 40, "size from rect");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
