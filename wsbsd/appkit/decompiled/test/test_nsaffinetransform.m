/* test_nsaffinetransform.m — behaviour checks for NSAffineTransform(NSAppKitAdditions) */
#import "../src/NSAffineTransform.h"
#import "../src/NSBezierPath.h"
#import <math.h>

static int gFails = 0;
#define CHECK(c, m) do { if (!(c)) { fprintf(stderr, "FAIL: %s\n", m); gFails++; } } while (0)
#define EQ(a,b) (fabs((a)-(b)) < 1e-9)

int main(void) {
    @autoreleasepool {
        /* CG bridge round-trip */
        CGAffineTransform cg = CGAffineTransformMake(2, 0, 0, 3, 10, 20);
        NSAffineTransform *t = [NSAffineTransform transformWithCGAffineTransform:cg];
        CGAffineTransform back = t.CGAffineTransform;
        CHECK(EQ(back.a,2)&&EQ(back.d,3)&&EQ(back.tx,10)&&EQ(back.ty,20), "CG bridge round-trip");
        NSAffineTransformStruct s = t.transformStruct;
        CHECK(EQ(s.m11,2)&&EQ(s.m22,3)&&EQ(s.tX,10)&&EQ(s.tY,20), "setCGAffineTransform fills struct");

        /* identity / reset */
        NSAffineTransform *id1 = [NSAffineTransform transform];
        CHECK([id1 isIdentity], "fresh transform is identity");
        CHECK(![t isIdentity], "scaled transform is not identity");
        [t reset];
        CHECK([t isIdentity], "reset -> identity");

        /* rectilinear: diagonal and anti-diagonal yes, shear no */
        NSAffineTransform *diag = [NSAffineTransform transformWithCGAffineTransform:CGAffineTransformMake(2,0,0,5,0,0)];
        CHECK([diag isRectilinear], "diagonal is rectilinear");
        NSAffineTransform *anti = [NSAffineTransform transformWithCGAffineTransform:CGAffineTransformMake(0,2,3,0,0,0)];
        CHECK([anti isRectilinear], "anti-diagonal is rectilinear");
        NSAffineTransform *shear = [NSAffineTransform transformWithCGAffineTransform:CGAffineTransformMake(1,0.5,0,1,0,0)];
        CHECK(![shear isRectilinear], "shear is not rectilinear");

        /* singular */
        NSAffineTransform *sing = [NSAffineTransform transformWithCGAffineTransform:CGAffineTransformMake(2,0,4,0,0,0)];
        CHECK([sing isSingular], "zero-determinant is singular");
        CHECK(![diag isSingular], "non-zero determinant not singular");

        /* inverse point/size round-trips */
        NSAffineTransform *m = [NSAffineTransform transform];
        [m scaleXBy:2 yBy:4];
        [m translateXBy:3 yBy:5];
        NSPoint p = NSMakePoint(7, 9);
        NSPoint fwd = [m transformPoint:p];
        NSPoint rt = [m inverseTransformPoint:fwd];
        CHECK(EQ(rt.x,7)&&EQ(rt.y,9), "inverseTransformPoint undoes transformPoint");
        NSSize sz = NSMakeSize(6, 8);
        NSSize fsz = [m transformSize:sz];
        NSSize rsz = [m inverseTransformSize:fsz];
        CHECK(EQ(rsz.width,6)&&EQ(rsz.height,8), "inverseTransformSize undoes transformSize");

        /* transformRect = scale+translate bounding box */
        NSAffineTransform *r = [NSAffineTransform transformWithCGAffineTransform:CGAffineTransformMake(2,0,0,2,10,20)];
        NSRect out = [r transformRect:NSMakeRect(1,1,3,4)];
        CHECK(EQ(out.origin.x,12)&&EQ(out.origin.y,22)&&EQ(out.size.width,6)&&EQ(out.size.height,8), "transformRect scales+translates");
        NSRect rinv = [r inverseTransformRect:out];
        CHECK(EQ(rinv.origin.x,1)&&EQ(rinv.origin.y,1)&&EQ(rinv.size.width,3)&&EQ(rinv.size.height,4), "inverseTransformRect undoes transformRect");

        /* transformBezierPath returns a transformed copy, original untouched */
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(0,0)];
        [path lineToPoint:NSMakePoint(1,1)];
        NSAffineTransform *tr = [NSAffineTransform transformWithCGAffineTransform:CGAffineTransformMake(2,0,0,2,0,0)];
        NSBezierPath *moved = [tr transformBezierPath:path];
        CHECK(moved != nil && moved != path, "transformBezierPath returns a new path");
        CGPoint pts[3]; NSPoint op[3];
        [moved elementAtIndex:1 associatedPoints:pts];
        [path  elementAtIndex:1 associatedPoints:op];
        CHECK(EQ(pts[0].x,2)&&EQ(pts[0].y,2), "path points transformed");
        CHECK(EQ(op[0].x,1)&&EQ(op[0].y,1), "original path unchanged");

        /* -set / -concat are no-ops without a current context (don't crash) */
        [id1 concat];
        [id1 set];
        CHECK(1, "set/concat safe with no current context");
    }
    fprintf(stderr, gFails ? "%d FAILED\n" : "all passed\n", gFails);
    return gFails == 0 ? 0 : 1;
}
