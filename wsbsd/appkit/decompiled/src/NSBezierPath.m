/*
 * NSBezierPath.m — 1:1 (core). See NSBezierPath.h for the interface evidence.
 *
 * Backed by a CGMutablePath (the real `_cgPath` ivar). Construction maps 1:1 to
 * CGPath operations; geometry queries delegate to CoreGraphics:
 *   isEmpty            -> CGPathIsEmpty
 *   currentPoint       -> CGPathGetCurrentPoint (AppKit raises if the path is
 *                         empty — "No current point" — modelled here)
 *   bounds             -> CGPathGetBoundingBox (tight bbox of the painted path)
 *   controlPointBounds -> CGPathGetPathBoundingBox (bbox incl. control points)
 *   element access     -> CGPathApply walk, mapping CGPathElementType to
 *                         NSBezierPathElement (move/line/curve/close).
 * Dashing, glyphs, flattening/reversing, stroke/fill drawing = stage2.
 */
#import "NSBezierPath.h"

static CGFloat sDefaultLineWidth = 1.0;
static CGFloat sDefaultFlatness = 0.6;
static CGFloat sDefaultMiterLimit = 10.0;
static NSLineCapStyle sDefaultLineCapStyle = NSLineCapStyleButt;
static NSLineJoinStyle sDefaultLineJoinStyle = NSLineJoinStyleMiter;
static NSWindingRule sDefaultWindingRule = NSWindingRuleNonZero;

@implementation NSBezierPath {
    CGMutablePathRef _path;          /* _cgPath */
    CGFloat _lineWidth, _miterLimit, _flatness;
    NSLineCapStyle _lineCapStyle;
    NSLineJoinStyle _lineJoinStyle;
    NSWindingRule _windingRule;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _path = CGPathCreateMutable();
        _lineWidth = sDefaultLineWidth;
        _flatness = sDefaultFlatness;
        _miterLimit = sDefaultMiterLimit;
        _lineCapStyle = sDefaultLineCapStyle;
        _lineJoinStyle = sDefaultLineJoinStyle;
        _windingRule = sDefaultWindingRule;
    }
    return self;
}

- (void)dealloc
{
    if (_path) CGPathRelease(_path);
}

+ (NSBezierPath *)bezierPath { return [[self alloc] init]; }

+ (NSBezierPath *)bezierPathWithRect:(CGRect)rect
{
    NSBezierPath *p = [self bezierPath];
    [p appendBezierPathWithRect:rect];
    return p;
}

+ (NSBezierPath *)bezierPathWithOvalInRect:(CGRect)rect
{
    NSBezierPath *p = [self bezierPath];
    [p appendBezierPathWithOvalInRect:rect];
    return p;
}

+ (NSBezierPath *)bezierPathWithRoundedRect:(CGRect)rect xRadius:(CGFloat)xRadius yRadius:(CGFloat)yRadius
{
    NSBezierPath *p = [self bezierPath];
    CGPathRef rr = CGPathCreateWithRoundedRect(rect, xRadius, yRadius, NULL);
    CGPathAddPath(p->_path, NULL, rr);
    CGPathRelease(rr);
    return p;
}

+ (NSBezierPath *)bezierPathWithCGPath:(CGPathRef)cgPath
{
    NSBezierPath *p = [self bezierPath];
    [p appendBezierPathWithCGPath:cgPath];
    return p;
}

/* --- class defaults --- */
+ (CGFloat)defaultLineWidth { return sDefaultLineWidth; }
+ (void)setDefaultLineWidth:(CGFloat)v { sDefaultLineWidth = v; }
+ (CGFloat)defaultFlatness { return sDefaultFlatness; }
+ (void)setDefaultFlatness:(CGFloat)v { sDefaultFlatness = v; }
+ (CGFloat)defaultMiterLimit { return sDefaultMiterLimit; }
+ (void)setDefaultMiterLimit:(CGFloat)v { sDefaultMiterLimit = v; }
+ (NSLineCapStyle)defaultLineCapStyle { return sDefaultLineCapStyle; }
+ (void)setDefaultLineCapStyle:(NSLineCapStyle)v { sDefaultLineCapStyle = v; }
+ (NSLineJoinStyle)defaultLineJoinStyle { return sDefaultLineJoinStyle; }
+ (void)setDefaultLineJoinStyle:(NSLineJoinStyle)v { sDefaultLineJoinStyle = v; }
+ (NSWindingRule)defaultWindingRule { return sDefaultWindingRule; }
+ (void)setDefaultWindingRule:(NSWindingRule)v { sDefaultWindingRule = v; }

/* --- construction --- */
- (void)moveToPoint:(CGPoint)point { CGPathMoveToPoint(_path, NULL, point.x, point.y); }
- (void)lineToPoint:(CGPoint)point { CGPathAddLineToPoint(_path, NULL, point.x, point.y); }
- (void)curveToPoint:(CGPoint)endPoint controlPoint1:(CGPoint)cp1 controlPoint2:(CGPoint)cp2
{
    CGPathAddCurveToPoint(_path, NULL, cp1.x, cp1.y, cp2.x, cp2.y, endPoint.x, endPoint.y);
}
- (void)closePath { CGPathCloseSubpath(_path); }

- (void)removeAllPoints
{
    CGPathRelease(_path);
    _path = CGPathCreateMutable();
}

/* --- appending --- */
- (void)appendBezierPath:(NSBezierPath *)path
{
    if (path && path->_path) CGPathAddPath(_path, NULL, path->_path);
}
- (void)appendBezierPathWithRect:(CGRect)rect { CGPathAddRect(_path, NULL, rect); }
- (void)appendBezierPathWithOvalInRect:(CGRect)rect { CGPathAddEllipseInRect(_path, NULL, rect); }
- (void)appendBezierPathWithCGPath:(CGPathRef)cgPath { if (cgPath) CGPathAddPath(_path, NULL, cgPath); }

- (void)appendBezierPathWithPoints:(const CGPoint *)points count:(NSInteger)count
{
    if (!points || count <= 0) return;
    /* AppKit: line to the first point if there is a current point, else move to
     * it; then line to the rest. */
    NSInteger start = 0;
    if (CGPathIsEmpty(_path)) {
        CGPathMoveToPoint(_path, NULL, points[0].x, points[0].y);
        start = 1;
    }
    for (NSInteger i = start; i < count; i++)
        CGPathAddLineToPoint(_path, NULL, points[i].x, points[i].y);
}

/* --- transform --- */
- (void)transformUsingAffineTransform:(NSAffineTransform *)transform
{
    NSAffineTransformStruct s = transform.transformStruct;
    CGAffineTransform t = CGAffineTransformMake(s.m11, s.m12, s.m21, s.m22, s.tX, s.tY);
    CGMutablePathRef np = CGPathCreateMutableCopyByTransformingPath(_path, &t);
    CGPathRelease(_path);
    _path = np;
}

/* --- queries --- */
- (BOOL)isEmpty { return CGPathIsEmpty(_path); }

- (CGPoint)currentPoint
{
    if (CGPathIsEmpty(_path))
        [NSException raise:NSGenericException format:@"No current point."];
    return CGPathGetCurrentPoint(_path);
}

- (CGRect)bounds { return CGPathGetBoundingBox(_path); }
- (CGRect)controlPointBounds { return CGPathGetPathBoundingBox(_path); }
- (CGPathRef)CGPath { return _path; }

/* element walk via CGPathApply */
struct NSBPWalk { NSInteger target; NSInteger cur; NSBezierPathElement type; CGPoint pts[3]; BOOL found; NSInteger count; };

static void NSBPApply(void *info, const CGPathElement *e)
{
    struct NSBPWalk *w = (struct NSBPWalk *)info;
    NSBezierPathElement type; CGPoint pts[3] = {0}; int npts = 0;
    switch (e->type) {
        case kCGPathElementMoveToPoint:    type = NSBezierPathElementMoveTo;  pts[0] = e->points[0]; npts = 1; break;
        case kCGPathElementAddLineToPoint: type = NSBezierPathElementLineTo;  pts[0] = e->points[0]; npts = 1; break;
        case kCGPathElementAddCurveToPoint:type = NSBezierPathElementCurveTo; pts[0] = e->points[0]; pts[1] = e->points[1]; pts[2] = e->points[2]; npts = 3; break;
        case kCGPathElementAddQuadCurveToPoint: /* promote quad to cubic-ish: AppKit stores curve */
                                           type = NSBezierPathElementCurveTo; pts[0] = e->points[0]; pts[1] = e->points[1]; npts = 2; break;
        case kCGPathElementCloseSubpath:   type = NSBezierPathElementClosePath; npts = 0; break;
        default: return;
    }
    if (w->cur == w->target) {
        w->type = type;
        for (int i = 0; i < npts; i++) w->pts[i] = pts[i];
        w->found = YES;
    }
    w->cur++;
    w->count++;
}

- (NSInteger)elementCount
{
    struct NSBPWalk w = {0}; w.target = -1;
    CGPathApply(_path, &w, NSBPApply);
    return w.count;
}

- (NSBezierPathElement)elementAtIndex:(NSInteger)index
{
    return [self elementAtIndex:index associatedPoints:NULL];
}

- (NSBezierPathElement)elementAtIndex:(NSInteger)index associatedPoints:(CGPoint *)points
{
    struct NSBPWalk w = {0}; w.target = index;
    CGPathApply(_path, &w, NSBPApply);
    if (!w.found)
        [NSException raise:NSRangeException format:@"element index %ld out of range", (long)index];
    if (points) { points[0] = w.pts[0]; points[1] = w.pts[1]; points[2] = w.pts[2]; }
    return w.type;
}

/* --- plain accessors --- */
- (CGFloat)lineWidth { return _lineWidth; }
- (void)setLineWidth:(CGFloat)v { _lineWidth = v; }
- (CGFloat)miterLimit { return _miterLimit; }
- (void)setMiterLimit:(CGFloat)v { _miterLimit = v; }
- (CGFloat)flatness { return _flatness; }
- (void)setFlatness:(CGFloat)v { _flatness = v; }
- (NSLineCapStyle)lineCapStyle { return _lineCapStyle; }
- (void)setLineCapStyle:(NSLineCapStyle)v { _lineCapStyle = v; }
- (NSLineJoinStyle)lineJoinStyle { return _lineJoinStyle; }
- (void)setLineJoinStyle:(NSLineJoinStyle)v { _lineJoinStyle = v; }
- (NSWindingRule)windingRule { return _windingRule; }
- (void)setWindingRule:(NSWindingRule)v { _windingRule = v; }

- (id)copyWithZone:(NSZone *)zone
{
    NSBezierPath *c = [[NSBezierPath alloc] init];
    CGPathRelease(c->_path);
    c->_path = CGPathCreateMutableCopy(_path);
    c->_lineWidth = _lineWidth; c->_miterLimit = _miterLimit; c->_flatness = _flatness;
    c->_lineCapStyle = _lineCapStyle; c->_lineJoinStyle = _lineJoinStyle; c->_windingRule = _windingRule;
    return c;
}

@end
