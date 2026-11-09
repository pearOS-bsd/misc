/* test_nsstringdrawingcontext.m — NSStringDrawingContext inputs/outputs. */
#import "../src/NSStringDrawingContext.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSStringDrawingContext *ctx = [[NSStringDrawingContext alloc] init];
        CHECK(ctx.actualScaleFactor == 1.0, "actualScaleFactor defaults 1.0");
        CHECK(CGRectEqualToRect(ctx.totalBounds, CGRectZero), "totalBounds defaults zero");
        CHECK(ctx.minimumScaleFactor == 0, "minimumScaleFactor default 0 (no scaling)");

        ctx.minimumScaleFactor = 0.5;
        ctx.minimumTrackingAdjustment = -2.0;
        ctx.maximumNumberOfLines = 3;
        CHECK(ctx.minimumScaleFactor == 0.5, "minimumScaleFactor set");
        CHECK(ctx.minimumTrackingAdjustment == -2.0, "minimumTrackingAdjustment set");
        CHECK(ctx.maximumNumberOfLines == 3, "maximumNumberOfLines set");

        /* the drawing pass fills the outputs */
        [ctx _setActualScaleFactor:0.75 totalBounds:CGRectMake(0, 0, 200, 40)];
        CHECK(ctx.actualScaleFactor == 0.75, "actualScaleFactor filled by draw");
        CHECK(ctx.totalBounds.size.width == 200 && ctx.totalBounds.size.height == 40, "totalBounds filled by draw");

        /* inputs unchanged by the draw */
        CHECK(ctx.minimumScaleFactor == 0.5, "inputs survive the draw");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
