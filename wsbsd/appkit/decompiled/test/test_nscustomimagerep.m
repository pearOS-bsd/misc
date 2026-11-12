/* test_nscustomimagerep.m */
#import "../src/NSCustomImageRep.h"

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)

@interface Painter : NSObject
@property NSInteger calls;
@property (weak) id lastRep;
- (void)paintRep:(id)rep;
@end
@implementation Painter
- (void)paintRep:(id)rep { self.calls++; self.lastRep = rep; }
@end

int main(void) {
    @autoreleasepool {
        /* modern block path */
        __block CGRect seen = CGRectZero; __block int blkCalls = 0;
        NSCustomImageRep *r = [[NSCustomImageRep alloc]
            initWithSize:CGSizeMake(10, 20) flipped:YES
            drawingHandler:^BOOL(CGRect dst){ seen = dst; blkCalls++; return YES; }];
        CHECK([r isKindOfClass:[NSImageRep class]], "is NSImageRep");
        CHECK(r.size.width == 10 && r.size.height == 20, "size stored");
        CHECK(r.isFlipped, "flipped stored");
        CHECK(r.drawingHandler != nil, "drawingHandler stored");
        CHECK(r.drawSelector == NULL && r.delegate == nil, "block path: no selector/delegate");

        /* draw invokes the handler with the dest rect = {0,0,size} */
        BOOL ok = [r draw];
        CHECK(ok && blkCalls == 1, "draw calls handler, returns its BOOL");
        CHECK(seen.size.width == 10 && seen.size.height == 20 && seen.origin.x == 0, "handler gets bounds rect");

        /* handler returning NO is propagated */
        NSCustomImageRep *rn = [[NSCustomImageRep alloc]
            initWithSize:CGSizeMake(1,1) flipped:NO drawingHandler:^BOOL(CGRect d){ return NO; }];
        CHECK(![rn draw], "draw returns NO from handler");
        CHECK(!rn.isFlipped, "flipped NO stored");

        /* legacy draw-selector path */
        Painter *p = [Painter new];
        NSCustomImageRep *rs = [[NSCustomImageRep alloc] initWithDrawSelector:@selector(paintRep:) delegate:p];
        CHECK(rs.drawSelector == @selector(paintRep:), "drawSelector stored");
        CHECK(rs.delegate == p && rs.drawingHandler == nil, "delegate stored, no block");
        BOOL ok2 = [rs draw];
        CHECK(ok2 && p.calls == 1 && p.lastRep == rs, "draw performs selector on delegate with rep");

        /* flipped is settable */
        rs.flipped = YES; CHECK(rs.isFlipped, "flipped setter");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
