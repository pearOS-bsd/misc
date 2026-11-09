/* test_nsgraphicscontext.m — NSGraphicsContext: wrap, current, save/restore. */
#import "../src/NSGraphicsContext.h"

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        /* a 1x1 bitmap CGContext to wrap */
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGContextRef cg = CGBitmapContextCreate(NULL, 1, 1, 8, 4, cs, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        CGColorSpaceRelease(cs);

        NSGraphicsContext *ctx = [NSGraphicsContext graphicsContextWithCGContext:cg flipped:YES];
        CHECK(ctx != nil, "context wraps CGContext");
        CHECK(ctx.CGContext == cg, "CGContext accessor returns the backing context");
        CHECK(ctx.isFlipped, "flipped flag set");
        CHECK(ctx.shouldAntialias, "shouldAntialias defaults YES");

        CGContextRef nullCtx = NULL;
        CHECK([NSGraphicsContext graphicsContextWithCGContext:nullCtx flipped:NO] == nil, "NULL CGContext -> nil");

        /* current context is thread-local */
        CHECK([NSGraphicsContext currentContext] == nil, "no current context initially");
        [NSGraphicsContext setCurrentContext:ctx];
        CHECK([NSGraphicsContext currentContext] == ctx, "setCurrentContext: installs it");

        /* save/restore via class methods operate on current context (no crash) */
        [NSGraphicsContext saveGraphicsState];
        ctx.shouldAntialias = NO;
        CHECK(!ctx.shouldAntialias, "antialias toggled off while saved");
        [NSGraphicsContext restoreGraphicsState];
        /* (CG gstate restored; our stored flag is not auto-reverted — matches that
         *  NSGraphicsContext does not snapshot its ObjC properties) */
        CHECK([NSGraphicsContext currentContext] == ctx, "current context unchanged after restore");

        /* instance save/restore balance */
        [ctx saveGraphicsState];
        [ctx saveGraphicsState];
        [ctx restoreGraphicsState];
        [ctx restoreGraphicsState];
        CHECK(1, "balanced instance save/restore does not crash");

        [NSGraphicsContext setCurrentContext:nil];
        CHECK([NSGraphicsContext currentContext] == nil, "current context cleared");

        /* settable state */
        ctx.compositingOperation = 2;
        ctx.patternPhase = CGPointMake(5, 7);
        CHECK(ctx.compositingOperation == 2, "compositingOperation stored");
        CHECK(ctx.patternPhase.x == 5 && ctx.patternPhase.y == 7, "patternPhase stored");

        CGContextRelease(cg);
        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
