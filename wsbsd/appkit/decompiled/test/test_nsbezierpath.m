/* test_nsbezierpath.m — NSBezierPath: element API, geometry over CGPath. */
#import "../src/NSBezierPath.h"
#import <math.h>

static int gFails = 0, gChecks = 0;
#define CHECK(cond, msg) do { gChecks++; if (!(cond)) { gFails++; \
    fprintf(stderr, "FAIL: %s  (%s:%d)\n", (msg), __FILE__, __LINE__); } } while (0)

int main(void)
{
    @autoreleasepool {
        NSBezierPath *p = [NSBezierPath bezierPath];
        CHECK(p.isEmpty, "fresh path is empty");
        CHECK(p.elementCount == 0, "fresh path has no elements");
        CHECK(p.lineWidth == 1.0, "default lineWidth 1.0");
        CHECK(p.miterLimit == 10.0, "default miterLimit 10.0");
        CHECK(p.windingRule == NSWindingRuleNonZero, "default winding nonzero");

        [p moveToPoint:CGPointMake(10, 20)];
        [p lineToPoint:CGPointMake(110, 20)];
        [p lineToPoint:CGPointMake(110, 70)];
        [p closePath];
        CHECK(!p.isEmpty, "path with elements is non-empty");
        CHECK(p.elementCount == 4, "move+line+line+close = 4 elements");

        /* element types + associated points */
        CGPoint pts[3] = {0};
        CHECK([p elementAtIndex:0 associatedPoints:pts] == NSBezierPathElementMoveTo, "el 0 is MoveTo");
        CHECK(pts[0].x == 10 && pts[0].y == 20, "MoveTo carries its point");
        CHECK([p elementAtIndex:1 associatedPoints:pts] == NSBezierPathElementLineTo, "el 1 is LineTo");
        CHECK(pts[0].x == 110 && pts[0].y == 20, "LineTo carries its point");
        CHECK([p elementAtIndex:3] == NSBezierPathElementClosePath, "el 3 is ClosePath");

        /* bounds = tight bbox of the triangle (10,20)-(110,20)-(110,70) */
        CGRect b = p.bounds;
        CHECK(fabs(b.origin.x - 10) < 1e-6 && fabs(b.origin.y - 20) < 1e-6, "bounds origin (10,20)");
        CHECK(fabs(b.size.width - 100) < 1e-6 && fabs(b.size.height - 50) < 1e-6, "bounds size 100x50");

        /* currentPoint after close returns to subpath start */
        CHECK(fabs(p.currentPoint.x - 10) < 1e-6, "currentPoint back at subpath start after close");

        /* curve element carries 3 points */
        NSBezierPath *c = [NSBezierPath bezierPath];
        [c moveToPoint:CGPointZero];
        [c curveToPoint:CGPointMake(100, 0) controlPoint1:CGPointMake(30, 50) controlPoint2:CGPointMake(70, 50)];
        CGPoint cp[3] = {0};
        CHECK([c elementAtIndex:1 associatedPoints:cp] == NSBezierPathElementCurveTo, "curve element type");
        CHECK(cp[0].x == 30 && cp[1].x == 70 && cp[2].x == 100, "curve carries cp1,cp2,end");

        /* rect convenience + copy independence */
        NSBezierPath *r = [NSBezierPath bezierPathWithRect:CGRectMake(0, 0, 40, 30)];
        CHECK(fabs(r.bounds.size.width - 40) < 1e-6, "rect path bounds width 40");
        NSBezierPath *r2 = [r copy];
        [r2 lineToPoint:CGPointMake(200, 200)];
        CHECK(r.elementCount != r2.elementCount, "copy is independent of original");

        /* oval bounds */
        NSBezierPath *o = [NSBezierPath bezierPathWithOvalInRect:CGRectMake(5, 5, 20, 10)];
        CHECK(fabs(o.bounds.size.width - 20) < 0.5, "oval bounds width ~20");

        /* empty currentPoint raises */
        NSBezierPath *e = [NSBezierPath bezierPath];
        BOOL raised = NO;
        @try { (void)e.currentPoint; } @catch (NSException *ex) { raised = YES; }
        CHECK(raised, "currentPoint on empty path raises");

        /* removeAllPoints resets */
        [p removeAllPoints];
        CHECK(p.isEmpty && p.elementCount == 0, "removeAllPoints empties the path");

        fprintf(stderr, "\n%d checks, %d failures\n", gChecks, gFails);
    }
    return gFails == 0 ? 0 : 1;
}
