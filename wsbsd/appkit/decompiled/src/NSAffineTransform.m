/*
 * NSAffineTransform.m — 1:1 (behavioral) reimplementation of the
 * NSAffineTransform (NSAppKitAdditions) category. See NSAffineTransform.h for
 * interface evidence. The base class is Foundation's; this file only adds the
 * AppKit category, built over the base's -transformStruct / -setTransformStruct:
 * / -invert / -transformPoint: / -transformSize: / NSCopying.
 */

#import "NSAffineTransform.h"
#import "NSBezierPath.h"

@implementation NSAffineTransform (NSAppKitAdditions)

/* --- CoreGraphics bridge --- */

+ (NSAffineTransform *)transformWithCGAffineTransform:(CGAffineTransform)t
{
    NSAffineTransform *xform = [[NSAffineTransform alloc] init];
    [xform setCGAffineTransform:t];
    return xform;
}

- (CGAffineTransform)CGAffineTransform
{
    NSAffineTransformStruct s = self.transformStruct;
    return CGAffineTransformMake(s.m11, s.m12, s.m21, s.m22, s.tX, s.tY);
}

- (void)setCGAffineTransform:(CGAffineTransform)t
{
    NSAffineTransformStruct s;
    s.m11 = t.a;  s.m12 = t.b;
    s.m21 = t.c;  s.m22 = t.d;
    s.tX  = t.tx; s.tY  = t.ty;
    self.transformStruct = s;
}

/* --- matrix predicates --- */

- (BOOL)isIdentity
{
    NSAffineTransformStruct s = self.transformStruct;
    return (s.m11 == 1.0 && s.m12 == 0.0 &&
            s.m21 == 0.0 && s.m22 == 1.0 &&
            s.tX  == 0.0 && s.tY  == 0.0);
}

- (BOOL)isRectilinear
{
    /* Axis-aligned rects stay axis-aligned iff the linear part is diagonal
     * (pure scale/translate) or anti-diagonal (a 90°/270° rotation+scale). */
    NSAffineTransformStruct s = self.transformStruct;
    return ((s.m12 == 0.0 && s.m21 == 0.0) ||
            (s.m11 == 0.0 && s.m22 == 0.0));
}

- (BOOL)isSingular
{
    /* Non-invertible iff the determinant of the linear part is zero. */
    NSAffineTransformStruct s = self.transformStruct;
    return (s.m11 * s.m22 - s.m21 * s.m12) == 0.0;
}

/* --- reset --- */

- (void)reset
{
    NSAffineTransformStruct s;
    s.m11 = 1.0; s.m12 = 0.0;
    s.m21 = 0.0; s.m22 = 1.0;
    s.tX  = 0.0; s.tY  = 0.0;
    self.transformStruct = s;
}

/* --- current-context application ---
 * -concat left-multiplies the receiver onto the current context's CTM.
 * -set makes the receiver the context transform. With CoreGraphics only a
 * concatenation is expressible; the exact base-CTM replacement -set performs
 * lives in the window-server graphics state. TODO(stage2): route through the
 * real NSGraphicsContext screen context so -set's absolute semantics match. */

- (void)concat
{
    CGContextRef ctx = [self _currentCGContext];
    if (ctx) CGContextConcatCTM(ctx, self.CGAffineTransform);
}

- (void)set
{
    CGContextRef ctx = [self _currentCGContext];
    if (ctx) CGContextConcatCTM(ctx, self.CGAffineTransform); /* stage2: absolute set */
}

- (CGContextRef)_currentCGContext
{
    /* Soft dependency on NSGraphicsContext so the category stays usable without
     * a drawing context (e.g. in the pure-math tests). */
    Class gcClass = NSClassFromString(@"NSGraphicsContext");
    if (!gcClass) return NULL;
    id gc = [gcClass performSelector:@selector(currentContext)];
    if (!gc || ![gc respondsToSelector:@selector(CGContext)]) return NULL;
    return (__bridge CGContextRef)[gc performSelector:@selector(CGContext)];
}

/* --- inverse mapping --- */

- (NSAffineTransform *)_inverse
{
    NSAffineTransform *inv = [self copy];
    [inv invert];
    return inv;
}

- (NSPoint)inverseTransformPoint:(NSPoint)p
{
    return [[self _inverse] transformPoint:p];
}

- (NSSize)inverseTransformSize:(NSSize)sz
{
    return [[self _inverse] transformSize:sz];
}

- (NSRect)inverseTransformRect:(NSRect)r
{
    return CGRectApplyAffineTransform(r, CGAffineTransformInvert(self.CGAffineTransform));
}

/* --- forward rect / bezier mapping --- */

- (NSRect)transformRect:(NSRect)r
{
    /* Bounding box of the four transformed corners. */
    return CGRectApplyAffineTransform(r, self.CGAffineTransform);
}

- (NSBezierPath *)transformBezierPath:(NSBezierPath *)path
{
    if (!path) return nil;
    NSBezierPath *copy = [path copy];
    [copy transformUsingAffineTransform:self];
    return copy;
}

@end
