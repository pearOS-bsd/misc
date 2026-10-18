/* The layer compositor: renders a presentation tree with the software rasterizer. */
#import "CALayerPrivate.h"
#include "CARaster.h"
#ifdef __APPLE__
#import <CoreText/CoreText.h>
#import <AppKit/AppKit.h>
#else
#import <CoreText/CoreText.h>
#endif

CFTimeInterval gCARenderTimeOverride = 0;

/* ---- colors and images -------------------------------------------------------------------------------------------------------------------------------------------- */
static RColor CAPremulColor(CGColorRef c, float opacity)
{
	RColor o = { 0, 0, 0, 0 };
	if (!c) return o;
	double v[4]; CAColorGetExtSRGB(c, v);
	for (int i = 0; i < 3; i++) v[i] = v[i] < 0 ? 0 : (v[i] > 1 ? 1 : v[i]);
	double a = v[3] * opacity; a = a < 0 ? 0 : (a > 1 ? 1 : a);
	o.r = (float)(v[0] * a); o.g = (float)(v[1] * a); o.b = (float)(v[2] * a); o.a = (float)a;
	return o;
}

@interface CARenderImage : NSObject { @public RSurf surf; CGFloat scale; }
@end
@implementation CARenderImage
- (void)dealloc { RSurfFree(&surf); }
@end
static NSMapTable *gImageCache;
static CARenderImage *CAImageFor(id contents)
{
	if (!contents || !CAIsImage(contents)) return nil;
	if (!gImageCache) gImageCache = [NSMapTable weakToStrongObjectsMapTable];
	CARenderImage *ci = [gImageCache objectForKey:contents];
	if (ci) return ci;
	CGImageRef img = (__bridge CGImageRef)contents; size_t w = CGImageGetWidth(img), h = CGImageGetHeight(img);
	if (!w || !h) return nil;
	ci = [CARenderImage new]; ci->surf = RSurfCreate((int)w, (int)h);
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(ci->surf.px, w, h, 8, (size_t)ci->surf.stride, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(cs);
	if (ctx) { CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), img); CGContextRelease(ctx); }
	/* the bitmap context has its origin at the bottom: flip the rows so row 0 is the top of the image */
	for (size_t y = 0; y < h / 2; y++) { uint8_t *a = ci->surf.px + y * ci->surf.stride, *b = ci->surf.px + (h - 1 - y) * ci->surf.stride; for (size_t x = 0; x < w * 4; x++) { uint8_t t = a[x]; a[x] = b[x]; b[x] = t; } }
	[gImageCache setObject:ci forKey:contents];
	return ci;
}

/* ---- the renderer ----------------------------------------------------------------------------------------------------------------------------------------------------- */
typedef struct { RSurf *dest; RClip clip; int ox, oy; } RCtx;

static RMat RM(CATransform3D t) { RMat m; memcpy(m.m, &t, sizeof m.m); return m; }
static RShape ShapeFor(CALayer *l, CGRect b)
{
	RShape s; s.r.x = b.origin.x; s.r.y = b.origin.y; s.r.w = b.size.width; s.r.h = b.size.height;
	double r = [l cornerRadius]; unsigned mask = (unsigned)[l maskedCorners];
	s.rad[0] = (mask & kCALayerMinXMinYCorner) ? r : 0; s.rad[1] = (mask & kCALayerMaxXMinYCorner) ? r : 0; s.rad[2] = (mask & kCALayerMaxXMaxYCorner) ? r : 0; s.rad[3] = (mask & kCALayerMinXMaxYCorner) ? r : 0;
	s.continuous = [[l cornerCurve] isEqualToString:@"continuous"];
	return s;
}
static BOOL HasRadius(const RShape *s) { return s->rad[0] > 0 || s->rad[1] > 0 || s->rad[2] > 0 || s->rad[3] > 0; }

static void RenderLayerEx(CALayer *l, RMat parent, RCtx *cx, BOOL root);
static void RenderLayer(CALayer *l, RMat parent, RCtx *cx) { RenderLayerEx(l, parent, cx, NO); }
static void DrawKindContent(CALayer *l, RMat M, RCtx *cx, float opacity);
static CGColorRef CALayerWhiteForText(void);

static void DrawContents(CALayer *l, RMat M, RCtx *cx, CGRect b, const RShape *shape, float opacity)
{
	id contents = [l contents];
	CARenderImage *ci = CAImageFor(contents); if (!ci) return;
	CGRect cr = [l contentsRect];
	double iw = ci->surf.w, ih = ci->surf.h, scale = [l contentsScale]; if (scale <= 0) scale = 1;
	RRect src = { cr.origin.x * iw, cr.origin.y * ih, cr.size.width * iw, cr.size.height * ih };
	double pw = src.w / scale, ph = src.h / scale;                              /* the size of the image part in points */
	NSString *g = [l contentsGravity];
	RRect dst = { b.origin.x, b.origin.y, b.size.width, b.size.height };
	if ([g isEqualToString:kCAGravityResize]) {}
	else if ([g isEqualToString:kCAGravityResizeAspect] || [g isEqualToString:kCAGravityResizeAspectFill]) {
		double k = [g isEqualToString:kCAGravityResizeAspect] ? fmin(b.size.width / pw, b.size.height / ph) : fmax(b.size.width / pw, b.size.height / ph);
		dst.w = pw * k; dst.h = ph * k; dst.x = b.origin.x + (b.size.width - dst.w) / 2; dst.y = b.origin.y + (b.size.height - dst.h) / 2;
	} else {
		dst.w = pw; dst.h = ph;
		dst.x = [g isEqualToString:kCAGravityLeft] || [g isEqualToString:kCAGravityTopLeft] || [g isEqualToString:kCAGravityBottomLeft] ? b.origin.x : ([g isEqualToString:kCAGravityRight] || [g isEqualToString:kCAGravityTopRight] || [g isEqualToString:kCAGravityBottomRight] ? b.origin.x + b.size.width - pw : b.origin.x + (b.size.width - pw) / 2);
		/* the layer y axis points down on screen here: "top" is the minimum y in an unflipped layer, which is drawn at the bottom of the screen */
		dst.y = [g isEqualToString:kCAGravityBottom] || [g isEqualToString:kCAGravityBottomLeft] || [g isEqualToString:kCAGravityBottomRight] ? b.origin.y : ([g isEqualToString:kCAGravityTop] || [g isEqualToString:kCAGravityTopLeft] || [g isEqualToString:kCAGravityTopRight] ? b.origin.y + b.size.height - ph : b.origin.y + (b.size.height - ph) / 2);
	}
	BOOL nearest = [[l magnificationFilter] isEqualToString:kCAFilterNearest];
	CGRect cc = [l contentsCenter];
	if (!(cc.origin.x == 0 && cc.origin.y == 0 && cc.size.width == 1 && cc.size.height == 1) && [g isEqualToString:kCAGravityResize]) {
		/* nine parts: the corners keep their size (in points), the edges and the middle stretch */
		double sx[4] = { src.x, src.x + cc.origin.x * src.w, src.x + (cc.origin.x + cc.size.width) * src.w, src.x + src.w };
		double sy[4] = { src.y, src.y + cc.origin.y * src.h, src.y + (cc.origin.y + cc.size.height) * src.h, src.y + src.h };
		double lw = (sx[1] - sx[0]) / scale, rw = (sx[3] - sx[2]) / scale, th = (sy[1] - sy[0]) / scale, bh = (sy[3] - sy[2]) / scale;
		if (lw + rw > dst.w) { double k = dst.w / (lw + rw); lw *= k; rw *= k; }
		if (th + bh > dst.h) { double k = dst.h / (th + bh); th *= k; bh *= k; }
		double dx[4] = { dst.x, dst.x + lw, dst.x + dst.w - rw, dst.x + dst.w }, dy[4] = { dst.y, dst.y + th, dst.y + dst.h - bh, dst.y + dst.h };
		for (int j = 0; j < 3; j++) for (int i = 0; i < 3; i++) {
			RRect s = { sx[i], sy[j], sx[i + 1] - sx[i], sy[j + 1] - sy[j] }, d = { dx[i], dy[j], dx[i + 1] - dx[i], dy[j + 1] - dy[j] };
			if (s.w > 0 && s.h > 0 && d.w > 0 && d.h > 0) RDrawImage(cx->dest, &cx->clip, M, &ci->surf, s, d, shape, opacity, nearest);
		}
		return;
	}
	RDrawImage(cx->dest, &cx->clip, M, &ci->surf, src, dst, shape, opacity, nearest);
}

/* the clip of a layer's sublayers: the clip of the layer intersected with the shape of its bounds */
/* the alpha mask of a CGPath mapped by m (an affine approximation of the matrix) */
static void CAFillPathAlpha(RSurf *alpha, CGPathRef path, RMat m)
{
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(alpha->px, alpha->w, alpha->h, 8, alpha->stride, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(cs);
	if (!ctx) return;
	/* the bitmap rows run downward in memory; the CTM maps layer coordinates to rows of the surface */
	CGContextTranslateCTM(ctx, 0, alpha->h); CGContextScaleCTM(ctx, 1, -1);
	CGContextConcatCTM(ctx, CGAffineTransformMake(m.m[0], m.m[1], m.m[4], m.m[5], m.m[12], m.m[13]));
	CGContextSetRGBFillColor(ctx, 1, 1, 1, 1); CGContextAddPath(ctx, path); CGContextFillPath(ctx);
	CGContextRelease(ctx);
}

static BOOL PushShapeClip(RCtx *cx, RMat M, const RShape *shape, RCtx *out, uint8_t **bufOut)
{
	RSurf *d = cx->dest; uint8_t *buf = calloc((size_t)d->w * d->h, 1);
	RSurf tmp = RSurfCreate(d->w, d->h);
	RColor white = { 1, 1, 1, 1 };
	RClip none = { cx->clip.x0, cx->clip.y0, cx->clip.x1, cx->clip.y1, cx->clip.mask, cx->clip.mstride };
	RFillShape(&tmp, &none, M, shape, white, 0);
	for (int y = 0; y < d->h; y++) for (int x = 0; x < d->w; x++) buf[(size_t)y * d->w + x] = tmp.px[(size_t)y * tmp.stride + x * 4 + 3];
	RSurfFree(&tmp);
	*out = *cx; out->clip.mask = buf; out->clip.mstride = d->w; *bufOut = buf;
	return YES;
}

static CGFloat Scale2D(RMat M) { return sqrt(fabs(M.m[0] * M.m[5] - M.m[1] * M.m[4])); }

static void RenderReplicated(CAReplicatorLayer *l, NSArray *subs, RMat M, RCtx *cx)
{
	NSInteger n = [l instanceCount]; if (n < 1) return;
	CGRect bb = [l bounds]; CGPoint ap = [l anchorPoint]; double ax = bb.origin.x + ap.x * bb.size.width, ay = bb.origin.y + ap.y * bb.size.height;
	RMat around = RMatIdentity(); around.m[12] = -ax; around.m[13] = -ay; RMat back = RMatIdentity(); back.m[12] = ax; back.m[13] = ay;
	RMat it = RMatMul(RMatMul(around, RM([l instanceTransform])), back), cur = RMatIdentity();
	double base[4] = { 1, 1, 1, 1 }; if ([l instanceColor]) CAColorGetExtSRGB([l instanceColor], base);
	for (NSInteger i = 0; i < n; i++) {
		RMat Mi = RMatMul(cur, M);
		double r = base[0] + i * [l instanceRedOffset], g = base[1] + i * [l instanceGreenOffset], b = base[2] + i * [l instanceBlueOffset], a = base[3] + i * [l instanceAlphaOffset];
		BOOL tinted = r != 1 || g != 1 || b != 1 || a != 1;
		if (!tinted) { for (CALayer *s in subs) RenderLayer(s, Mi, cx); }
		else {
			RSurf grp = RSurfCreate(cx->dest->w, cx->dest->h); RCtx gc = { &grp, { 0, 0, grp.w, grp.h, NULL, 0 }, 0, 0 };
			for (CALayer *s in subs) RenderLayer(s, Mi, &gc);
			r = fmin(1, fmax(0, r)); g = fmin(1, fmax(0, g)); b = fmin(1, fmax(0, b)); a = fmin(1, fmax(0, a));
			for (int y = 0; y < grp.h; y++) for (int x = 0; x < grp.w; x++) { uint8_t *p = grp.px + (size_t)y * grp.stride + x * 4; p[0] = (uint8_t)(p[0] * b * a + 0.5); p[1] = (uint8_t)(p[1] * g * a + 0.5); p[2] = (uint8_t)(p[2] * r * a + 0.5); p[3] = (uint8_t)(p[3] * a + 0.5); }
			RComposite(cx->dest, &grp, 0, 0, 1, &cx->clip); RSurfFree(&grp);
		}
		cur = RMatMul(it, cur);
	}
}

static void RenderContent(CALayer *l, RMat M, RCtx *cx, float opacity)
{
	CGRect b = [l bounds];
	RShape shape = ShapeFor(l, b);
	CGColorRef bg = [l backgroundColor];
	if (bg) RFillShape(cx->dest, &cx->clip, M, &shape, CAPremulColor(bg, opacity), 0);
	DrawContents(l, M, cx, b, (HasRadius(&shape) || [l masksToBounds]) ? &shape : NULL, opacity);
	DrawKindContent(l, M, cx, opacity);
	NSArray *subs = [l _sublayerArray];
	BOOL anyZ = NO; for (CALayer *s in subs) if ([s zPosition] != 0) { anyZ = YES; break; }
	if (anyZ) subs = [subs sortedArrayWithOptions:NSSortStable usingComparator:^NSComparisonResult(CALayer *a, CALayer *b2) { CGFloat x = [a zPosition], y = [b2 zPosition]; return x < y ? NSOrderedAscending : (x > y ? NSOrderedDescending : NSOrderedSame); }];
	RCtx sub = *cx; uint8_t *buf = NULL;
	if ([l masksToBounds]) PushShapeClip(cx, M, &shape, &sub, &buf);
	if ([l isKindOfClass:[CAReplicatorLayer class]]) RenderReplicated((CAReplicatorLayer *)l, subs, M, &sub);
	else for (CALayer *s in subs) RenderLayer(s, M, &sub);
	free(buf);
	double bw = [l borderWidth];
	if (bw > 0) RStrokeShape(cx->dest, &cx->clip, M, &shape, bw, CAPremulColor([l borderColor], opacity));
}

/* ---- content drawn with CoreGraphics (shape, text) or by the rasterizer (gradient) -------------------------------------------------------------------------------- */
/* the elements of a path as polylines sampled uniformly in the curve parameter: strokeStart / strokeEnd cut the path in that parameter (each element is one unit) */
typedef struct { CGPoint pt[26]; int n; int move; } PElem;
typedef struct { PElem *e; int n, cap; CGPoint cur, start; } PElems;
static PElem *PElemNew(PElems *p) { if (p->n == p->cap) { p->cap = p->cap ? p->cap * 2 : 16; p->e = realloc(p->e, p->cap * sizeof(PElem)); } PElem *x = &p->e[p->n++]; x->n = 0; x->move = 0; return x; }
static void FlattenApply(void *info, const CGPathElement *e)
{
	PElems *p = info; PElem *x;
	switch (e->type) {
	case kCGPathElementMoveToPoint: x = PElemNew(p); x->move = 1; x->pt[x->n++] = e->points[0]; p->cur = p->start = e->points[0]; break;
	case kCGPathElementAddLineToPoint: x = PElemNew(p); x->pt[x->n++] = p->cur; x->pt[x->n++] = e->points[0]; p->cur = e->points[0]; break;
	case kCGPathElementAddQuadCurveToPoint: x = PElemNew(p); x->pt[x->n++] = p->cur; for (int i = 1; i <= 16; i++) { double t = i / 16.0, v = 1 - t; x->pt[x->n++] = CGPointMake(v * v * p->cur.x + 2 * v * t * e->points[0].x + t * t * e->points[1].x, v * v * p->cur.y + 2 * v * t * e->points[0].y + t * t * e->points[1].y); } p->cur = e->points[1]; break;
	case kCGPathElementAddCurveToPoint: x = PElemNew(p); x->pt[x->n++] = p->cur; for (int i = 1; i <= 24; i++) { double t = i / 24.0, v = 1 - t; x->pt[x->n++] = CGPointMake(v * v * v * p->cur.x + 3 * v * v * t * e->points[0].x + 3 * v * t * t * e->points[1].x + t * t * t * e->points[2].x, v * v * v * p->cur.y + 3 * v * v * t * e->points[0].y + 3 * v * t * t * e->points[1].y + t * t * t * e->points[2].y); } p->cur = e->points[2]; break;
	case kCGPathElementCloseSubpath: x = PElemNew(p); x->pt[x->n++] = p->cur; x->pt[x->n++] = p->start; p->cur = p->start; break;
	}
}
static CGPathRef TrimPath(CGPathRef path, double a, double b)
{
	PElems p = { 0 }; CGPathApply(path, &p, FlattenApply);
	int ne = 0; for (int i = 0; i < p.n; i++) if (!p.e[i].move) ne++;
	CGMutablePathRef out = CGPathCreateMutable(); double from = a * ne, to = b * ne; int k = 0; BOOL open = NO;
	for (int i = 0; i < p.n; i++) {
		PElem *x = &p.e[i]; if (x->move) { open = NO; continue; }
		double e0 = k, e1 = k + 1; k++;
		if (e1 < from || e0 > to) { open = NO; continue; }
		double u0 = fmax(0, from - e0), u1 = fmin(1, to - e0);
		int segs = x->n - 1;
		for (int j = 0; j < segs; j++) {
			double s0 = (double)j / segs, s1 = (double)(j + 1) / segs; if (s1 <= u0 || s0 >= u1) { continue; }
			double t0 = fmax(0, (u0 - s0) * segs), t1 = fmin(1, (u1 - s0) * segs);
			CGPoint p0 = x->pt[j], p1 = x->pt[j + 1];
			CGPoint q0 = CGPointMake(p0.x + (p1.x - p0.x) * t0, p0.y + (p1.y - p0.y) * t0), q1 = CGPointMake(p0.x + (p1.x - p0.x) * t1, p0.y + (p1.y - p0.y) * t1);
			if (!open) { CGPathMoveToPoint(out, NULL, q0.x, q0.y); open = YES; }
			CGPathAddLineToPoint(out, NULL, q1.x, q1.y);
		}
		if (u1 < 1) open = NO;
	}
	free(p.e);
	return out;
}

static void FlipRows(RSurf *s) { for (int y = 0; y < s->h / 2; y++) { uint8_t *a = s->px + (size_t)y * s->stride, *b = s->px + (size_t)(s->h - 1 - y) * s->stride; for (int x = 0; x < s->w * 4; x++) { uint8_t t = a[x]; a[x] = b[x]; b[x] = t; } } }
static CGContextRef BitmapFor(RSurf *s, CGFloat scale)
{
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(s->px, s->w, s->h, 8, s->stride, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(cs);
	if (ctx) { CGContextScaleCTM(ctx, scale, scale); CGContextSetShouldSmoothFonts(ctx, false); CGContextSetAllowsFontSmoothing(ctx, false); }
	return ctx;
}
static void CGSetColor(CGContextRef c, CGColorRef col, BOOL fill)
{
	double v[4]; CAColorGetExtSRGB(col, v);
	for (int i = 0; i < 3; i++) v[i] = v[i] < 0 ? 0 : (v[i] > 1 ? 1 : v[i]);
	if (fill) CGContextSetRGBFillColor(c, v[0], v[1], v[2], v[3]); else CGContextSetRGBStrokeColor(c, v[0], v[1], v[2], v[3]);
}
static void DrawShapeLayer(CAShapeLayer *l, RSurf *bmp, CGFloat scale)
{
	CGPathRef path = [l path]; if (!path) return;
	CGContextRef c = BitmapFor(bmp, scale); if (!c) return;
	CGRect b = [l bounds]; CGContextTranslateCTM(c, -b.origin.x, -b.origin.y);
	CGColorRef fc = [l fillColor], sc = [l strokeColor];
	double s0 = [l strokeStart], s1 = [l strokeEnd];
	if (fc) { CGSetColor(c, fc, YES); CGContextAddPath(c, path); if ([[l fillRule] isEqualToString:kCAFillRuleEvenOdd]) CGContextEOFillPath(c); else CGContextFillPath(c); }
	if (sc && [l lineWidth] > 0) {
		CGSetColor(c, sc, NO); CGContextSetLineWidth(c, [l lineWidth]); CGContextSetMiterLimit(c, [l miterLimit]);
		NSString *cap = [l lineCap], *join = [l lineJoin];
		CGContextSetLineCap(c, [cap isEqualToString:kCALineCapRound] ? kCGLineCapRound : ([cap isEqualToString:kCALineCapSquare] ? kCGLineCapSquare : kCGLineCapButt));
		CGContextSetLineJoin(c, [join isEqualToString:kCALineJoinRound] ? kCGLineJoinRound : ([join isEqualToString:kCALineJoinBevel] ? kCGLineJoinBevel : kCGLineJoinMiter));
		NSArray *dash = [l lineDashPattern];
		if (dash.count) { CGFloat d[32]; int n = 0; for (NSNumber *x in dash) if (n < 32) d[n++] = [x doubleValue]; CGContextSetLineDash(c, [l lineDashPhase], d, n); }
		CGPathRef sp = (s0 > 0 || s1 < 1) ? TrimPath(path, fmax(0, s0), fmin(1, s1)) : path;
		CGContextAddPath(c, sp); CGContextStrokePath(c);
	}
	CGContextRelease(c);
}
#ifdef __APPLE__
static void DrawTextLayer(CATextLayer *l, RSurf *bmp, CGFloat scale)
{
	id str = [l string]; if (!str) return;
	CGRect b = [l bounds]; CGFloat fs = [l fontSize];
	NSMutableAttributedString *as;
	if ([str isKindOfClass:[NSAttributedString class]]) as = [str mutableCopy];
	else {
		CGColorRef fg = [l foregroundColor]; CTFontRef font = (CTFontRef)[l font];
		CTFontRef f = font ? (CTFontRef)CFRetain(font) : CTFontCreateWithName(CFSTR("Helvetica"), fs, NULL);
		if (font && CTFontGetSize(f) != fs) { CTFontRef f2 = CTFontCreateCopyWithAttributes(f, fs, NULL, NULL); CFRelease(f); f = f2; }
		as = [[NSMutableAttributedString alloc] initWithString:[str description] attributes:@{ (__bridge id)kCTFontAttributeName: (__bridge id)f, (__bridge id)kCTForegroundColorAttributeName: (__bridge id)(fg ?: CALayerWhiteForText()) }];
		CFRelease(f);
	}
	NSString *am = [l alignmentMode]; CTTextAlignment ta = [am isEqualToString:kCAAlignmentCenter] ? kCTTextAlignmentCenter : ([am isEqualToString:kCAAlignmentRight] ? kCTTextAlignmentRight : ([am isEqualToString:kCAAlignmentJustified] ? kCTTextAlignmentJustified : kCTTextAlignmentNatural));
	CTLineBreakMode lb = [l isWrapped] ? kCTLineBreakByWordWrapping : kCTLineBreakByClipping;
	NSString *tm = [l truncationMode];
	if (![l isWrapped]) lb = [tm isEqualToString:kCATruncationEnd] ? kCTLineBreakByTruncatingTail : ([tm isEqualToString:kCATruncationStart] ? kCTLineBreakByTruncatingHead : ([tm isEqualToString:kCATruncationMiddle] ? kCTLineBreakByTruncatingMiddle : kCTLineBreakByClipping));
	CTParagraphStyleSetting set[2] = { { kCTParagraphStyleSpecifierAlignment, sizeof ta, &ta }, { kCTParagraphStyleSpecifierLineBreakMode, sizeof lb, &lb } };
	CTParagraphStyleRef ps = CTParagraphStyleCreate(set, 2);
	[as addAttribute:(__bridge id)kCTParagraphStyleAttributeName value:(__bridge id)ps range:NSMakeRange(0, as.length)]; CFRelease(ps);
	CGContextRef c = BitmapFor(bmp, scale); if (!c) return;
	CGContextTranslateCTM(c, -b.origin.x, -b.origin.y);
	CTFramesetterRef fsr = CTFramesetterCreateWithAttributedString((__bridge CFAttributedStringRef)as);
	CGMutablePathRef pp = CGPathCreateMutable(); CGPathAddRect(pp, NULL, b);
	CTFrameRef fr = CTFramesetterCreateFrame(fsr, CFRangeMake(0, 0), pp, NULL);
	if ([l isWrapped] || ![[l truncationMode] isEqualToString:kCATruncationNone]) CTFrameDraw(fr, c);
	else CTFrameDraw(fr, c);
	CFRelease(fr); CFRelease(fsr); CGPathRelease(pp); CGContextRelease(c);
}
#else
static void DrawTextLayer(CATextLayer *l, RSurf *bmp, CGFloat scale)
{
	/* without CoreText: the string is laid out with the toy text API of CoreGraphics (the cairo text of Opal) */
	id str = [l string]; if (!str) return;
	NSString *text = [str isKindOfClass:[NSAttributedString class]] ? [(NSAttributedString *)str string] : [str description];
	CGRect b = [l bounds]; CGFloat fs = [l fontSize]; if (fs <= 0) fs = 36;
	CGContextRef c = BitmapFor(bmp, scale); if (!c) return;
	CGContextTranslateCTM(c, -b.origin.x, -b.origin.y);
	CGColorRef fg = [l foregroundColor] ?: CALayerWhiteForText(); CGSetColor(c, fg, YES);
	CGContextSelectFont(c, "Helvetica", fs, kCGEncodingMacRoman);
	NSMutableArray *lines = [NSMutableArray array];
	if ([l isWrapped]) {
		NSMutableString *cur = [NSMutableString string];
		for (NSString *w in [text componentsSeparatedByString:@" "]) {
			NSString *t = cur.length ? [NSString stringWithFormat:@"%@ %@", cur, w] : w;
			CGContextSetTextPosition(c, 0, 0); CGContextSetTextDrawingMode(c, kCGTextInvisible); CGContextShowText(c, [t UTF8String], strlen([t UTF8String]));
			if (CGContextGetTextPosition(c).x > b.size.width && cur.length) { [lines addObject:[cur copy]]; [cur setString:w]; } else { [cur setString:t]; }
		}
		if (cur.length) [lines addObject:cur];
	} else [lines addObject:text];
	CGFloat lh = fs * 1.15, y = b.origin.y + b.size.height - fs;
	for (NSString *ln in lines) {
		const char *u = [ln UTF8String]; size_t n = strlen(u);
		CGContextSetTextDrawingMode(c, kCGTextInvisible); CGContextSetTextPosition(c, 0, 0); CGContextShowText(c, u, n); CGFloat w = CGContextGetTextPosition(c).x;
		NSString *am = [l alignmentMode]; CGFloat x = b.origin.x;
		if ([am isEqualToString:kCAAlignmentCenter]) x += (b.size.width - w) / 2; else if ([am isEqualToString:kCAAlignmentRight]) x += b.size.width - w;
		CGContextSetTextDrawingMode(c, kCGTextFill); CGContextShowTextAtPoint(c, x, y, u, n);
		y -= lh;
	}
	CGContextRelease(c);
}
#endif
static CGColorRef CALayerWhiteForText(void) { static CGColorRef c; if (!c) { CGFloat v[4] = { 1, 1, 1, 1 }; CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); c = CGColorCreate(cs, v); CGColorSpaceRelease(cs); } return c; }

static void DrawGradientLayer(CAGradientLayer *l, RSurf *bmp, CGFloat scale)
{
	NSArray *cols = [l colors]; if (cols.count < 1) return;
	NSArray *locs = [l locations]; int n = (int)cols.count;
	double (*rgba)[4] = malloc(sizeof(double[4]) * n); double *pos = malloc(sizeof(double) * n);
	for (int i = 0; i < n; i++) { CAColorGetExtSRGB((__bridge CGColorRef)cols[i], rgba[i]); for (int k = 0; k < 3; k++) rgba[i][k] = fmin(1, fmax(0, rgba[i][k])); pos[i] = locs.count == n ? [locs[i] doubleValue] : (n > 1 ? (double)i / (n - 1) : 0); }
	CGRect b = [l bounds]; CGPoint sp = [l startPoint], ep = [l endPoint]; NSString *type = [l type];
	for (int y = 0; y < bmp->h; y++) for (int x = 0; x < bmp->w; x++) {
		double lx = (x + 0.5) / scale / b.size.width, ly = (y + 0.5) / scale / b.size.height;     /* unit coordinates, y up like the layer */
		double t;
		if ([type isEqualToString:kCAGradientLayerRadial]) { double rx = fabs(ep.x - sp.x), ry = fabs(ep.y - sp.y); double dx = rx ? (lx - sp.x) / rx : 0, dy = ry ? (ly - sp.y) / ry : 0; t = sqrt(dx * dx + dy * dy); }
		else if ([type isEqualToString:kCAGradientLayerConic]) { double ang = atan2(ly - sp.y, lx - sp.x), a0 = atan2(ep.y - sp.y, ep.x - sp.x); t = (ang - a0) / (2 * M_PI); t -= floor(t); }
		else { double dx = ep.x - sp.x, dy = ep.y - sp.y, len2 = dx * dx + dy * dy; t = len2 > 0 ? ((lx - sp.x) * dx + (ly - sp.y) * dy) / len2 : 0; }
		double c[4];
		if (t <= pos[0]) memcpy(c, rgba[0], sizeof c);
		else if (t >= pos[n - 1]) memcpy(c, rgba[n - 1], sizeof c);
		else { int i = 0; while (i < n - 2 && t > pos[i + 1]) i++; double f = (t - pos[i]) / (pos[i + 1] - pos[i]); for (int k = 0; k < 4; k++) c[k] = rgba[i][k] + (rgba[i + 1][k] - rgba[i][k]) * f; }
		uint8_t *p = bmp->px + (size_t)y * bmp->stride + x * 4;
		/* the rows of the bitmap run with the layer y (see FlipRows): the y of the pixel is the layer y */
		p[0] = (uint8_t)(c[2] * c[3] * 255 + 0.5); p[1] = (uint8_t)(c[1] * c[3] * 255 + 0.5); p[2] = (uint8_t)(c[0] * c[3] * 255 + 0.5); p[3] = (uint8_t)(c[3] * 255 + 0.5);
	}
	free(rgba); free(pos);
}

/* draws the content of the layer kinds that have one */
static void DrawKindContent(CALayer *l, RMat M, RCtx *cx, float opacity)
{
	BOOL isShape = [l isKindOfClass:[CAShapeLayer class]], isText = [l isKindOfClass:[CATextLayer class]], isGrad = [l isKindOfClass:[CAGradientLayer class]];
	if (!isShape && !isText && !isGrad) return;
	CGRect b = [l bounds]; if (b.size.width <= 0 || b.size.height <= 0) return;
	CGFloat sc = ceil(fmax(1.0, Scale2D(M))); int w = (int)ceil(b.size.width * sc), h = (int)ceil(b.size.height * sc);
	if (w > 4096 || h > 4096) return;
	RSurf bmp = RSurfCreate(w, h);
	if (isShape) { DrawShapeLayer((CAShapeLayer *)l, &bmp, sc); FlipRows(&bmp); }
	else if (isText) { DrawTextLayer((CATextLayer *)l, &bmp, sc); FlipRows(&bmp); }
	else DrawGradientLayer((CAGradientLayer *)l, &bmp, sc);
	RRect src = { 0, 0, w, h }, dst = { b.origin.x, b.origin.y, b.size.width, b.size.height };
	RShape shape = ShapeFor(l, b);
	RDrawImage(cx->dest, &cx->clip, M, &bmp, src, dst, HasRadius(&shape) ? &shape : NULL, opacity, 0);
	RSurfFree(&bmp);
}

static BOOL NeedsGroup(CALayer *l)
{
	float op = [l opacity];
	if (op < 1 && [l allowsGroupOpacity] && ([[l _sublayerArray] count] || ([l borderWidth] > 0 && ([l backgroundColor] || [l contents])))) return YES;
	if ([l shadowOpacity] > 0 || [l mask] || [l shouldRasterize]) return YES;
	return NO;
}

static void ExtentOf(CALayer *l, RMat parent, double *minx, double *miny, double *maxx, double *maxy, int depth, BOOL root)
{
	RMat M = root ? parent : RMatMul(RM([l _localToSuperMatrix]), parent);
	CGRect b = [l bounds]; double xs[4] = { b.origin.x, b.origin.x + b.size.width, b.origin.x, b.origin.x + b.size.width }, ys[4] = { b.origin.y, b.origin.y, b.origin.y + b.size.height, b.origin.y + b.size.height };
	for (int i = 0; i < 4; i++) {
		double a = xs[i] * M.m[0] + ys[i] * M.m[4] + M.m[12], c = xs[i] * M.m[1] + ys[i] * M.m[5] + M.m[13], w = xs[i] * M.m[3] + ys[i] * M.m[7] + M.m[15];
		if (w <= 1e-6) { *minx = -1e9; *miny = -1e9; *maxx = 1e9; *maxy = 1e9; return; }
		a /= w; c /= w; if (a < *minx) *minx = a; if (a > *maxx) *maxx = a; if (c < *miny) *miny = c; if (c > *maxy) *maxy = c;
	}
	if (![l masksToBounds] && depth < 32) for (CALayer *s in [l _sublayerArray]) ExtentOf(s, M, minx, miny, maxx, maxy, depth + 1, NO);
}

/* renders one layer (and its sublayers); `parent` maps the coordinates of the superlayer's content to the surface */
static void RenderLayerEx(CALayer *l, RMat parent, RCtx *cx, BOOL isRoot)
{
	if ([l isHidden]) return;
	float opacity = [l opacity]; if (opacity <= 0) return;
	RMat M = isRoot ? parent : RMatMul(RM([l _localToSuperMatrix]), parent);
	CGRect b = [l bounds];
	if ((b.size.width <= 0 || b.size.height <= 0) && ![[l _sublayerArray] count]) return;
	if (![l isDoubleSided]) {
		/* a layer seen from behind is not drawn: the orientation of its projected plane */
		double det = M.m[0] * M.m[5] - M.m[1] * M.m[4]; if (det < 0 && M.m[3] == 0 && M.m[7] == 0) return;
	}
	if (!NeedsGroup(l)) { RenderContent(l, M, cx, opacity); return; }
	/* a group: the layer and its sublayers are drawn together, then shadow, mask and opacity are applied */
	double minx = 1e30, miny = 1e30, maxx = -1e30, maxy = -1e30;
	ExtentOf(l, parent, &minx, &miny, &maxx, &maxy, 0, isRoot);
	double blur = [l shadowOpacity] > 0 ? [l shadowRadius] * Scale2D(M) * 1.5 + 2 : 0;
	CGSize so = [l shadowOffset];
	double sox = so.width * M.m[0] + so.height * M.m[4], soy = so.width * M.m[1] + so.height * M.m[5];
	int x0 = (int)floor(fmin(minx, minx + sox) - blur) - 1, y0 = (int)floor(fmin(miny, miny + soy) - blur) - 1, x1 = (int)ceil(fmax(maxx, maxx + sox) + blur) + 1, y1 = (int)ceil(fmax(maxy, maxy + soy) + blur) + 1;
	if (x0 < cx->clip.x0) x0 = cx->clip.x0; if (y0 < cx->clip.y0) y0 = cx->clip.y0; if (x1 > cx->clip.x1) x1 = cx->clip.x1; if (y1 > cx->clip.y1) y1 = cx->clip.y1;
	if (x1 <= x0 || y1 <= y0) return;
	RSurf grp = RSurfCreate(x1 - x0, y1 - y0);
	RMat shift = RMatIdentity(); shift.m[12] = -x0; shift.m[13] = -y0;
	RCtx gc = { &grp, { 0, 0, grp.w, grp.h, NULL, 0 }, 0, 0 };
	RMat Mg = RMatMul(M, shift);
	/* the layer's own content is drawn with full opacity into the group; the opacity is applied when the group is composited */
	RenderContent(l, Mg, &gc, 1.0f);
	CALayer *mask = [l mask];
	if (mask) {
		RSurf ms = RSurfCreate(grp.w, grp.h); RCtx mc = { &ms, { 0, 0, ms.w, ms.h, NULL, 0 }, 0, 0 };
		RenderLayer(mask, Mg, &mc);
		for (int y = 0; y < grp.h; y++) for (int x = 0; x < grp.w; x++) { uint8_t *p = grp.px + (size_t)y * grp.stride + x * 4, a = ms.px[(size_t)y * ms.stride + x * 4 + 3]; for (int k = 0; k < 4; k++) p[k] = (uint8_t)((p[k] * a + 127) / 255); }
		RSurfFree(&ms);
	}
	float so_ = [l shadowOpacity];
	if (so_ > 0) {
		RSurf sh = RSurfCreate(grp.w, grp.h); RColor tint = CAPremulColor([l shadowColor], 1); RColor tc = { tint.a ? tint.r / tint.a : 0, tint.a ? tint.g / tint.a : 0, tint.a ? tint.b / tint.a : 0, tint.a * so_ };
		RSurf alpha = RSurfCreate(grp.w, grp.h);
		CGPathRef sp = [l shadowPath];
		if (sp) CAFillPathAlpha(&alpha, sp, Mg);
		else memcpy(alpha.px, grp.px, (size_t)grp.stride * grp.h);
		{ static double k = 0; if (k == 0) { const char *e = getenv("CA_SHADOW_K"); k = e ? atof(e) : 1.0; } RShadowFromAlpha(&sh, &alpha, [l shadowRadius] * k * Scale2D(M), tc); }
		RSurfFree(&alpha);
		RComposite(cx->dest, &sh, x0 + (int)lround(sox), y0 + (int)lround(soy), opacity, &cx->clip);
		RSurfFree(&sh);
	}
	RComposite(cx->dest, &grp, x0, y0, opacity, &cx->clip);
	RSurfFree(&grp);
}

/* a layer tree drawn into a CoreGraphics context. The layer space has y up; when the user space of the context is flipped (y down, as inside a flipped view) the layer bounds are mapped to it from the top:
 * user y = (2 * bounds.origin.y + bounds.size.height) - layer y. rootMode: the layer itself is drawn at its own origin (no position, no transform). */
static void CADrawTree(CALayer *tree, CGContextRef ctx, BOOL rootMode)
{
	CGRect clip = CGContextGetClipBoundingBox(ctx);
	CGAffineTransform ctm = CGContextGetCTM(ctx);
	BOOL flip = (ctm.a * ctm.d - ctm.b * ctm.c) < 0;
	double s = sqrt(fabs(ctm.a * ctm.d - ctm.b * ctm.c)); if (s < 1) s = 1; if (s > 4) s = 4;
	CGRect bnds = [tree bounds]; double Hb = 2 * bnds.origin.y + bnds.size.height;
	double minx = 1e30, miny = 1e30, maxx = -1e30, maxy = -1e30;
	ExtentOf(tree, RMatIdentity(), &minx, &miny, &maxx, &maxy, 0, rootMode);
	if (minx > maxx) return;
	double uy0 = flip ? Hb - maxy : miny, uy1 = flip ? Hb - miny : maxy;                 /* the extent in user space */
	CGRect ext = CGRectMake(minx - 40, uy0 - 40, maxx - minx + 80, uy1 - uy0 + 80);
	if (!isfinite(clip.origin.x) || !isfinite(clip.origin.y) || !isfinite(clip.size.width) || !isfinite(clip.size.height)) clip = ext;      /* a context that cannot tell its clip (Opal) */
	CGRect r = CGRectIntersection(clip, ext); if (CGRectIsNull(r) || r.size.width <= 0 || r.size.height <= 0) return;
	r = CGRectMake(floor(r.origin.x), floor(r.origin.y), ceil(r.size.width + 1), ceil(r.size.height + 1));
	int w = (int)ceil(r.size.width * s), h = (int)ceil(r.size.height * s); if (w <= 0 || h <= 0 || w > 8192 || h > 8192) return;
	double ymin = flip ? Hb - (r.origin.y + r.size.height) : r.origin.y;                   /* the layer y of the first row */
	RSurf surf = RSurfCreate(w, h);
	RMat M = RMatIdentity(); M.m[0] = s; M.m[5] = s; M.m[12] = -r.origin.x * s; M.m[13] = -ymin * s;
	RCtx cx = { &surf, { 0, 0, w, h, NULL, 0 }, 0, 0 };
	RenderLayerEx(tree, M, &cx, rootMode);
	if (!flip) FlipRows(&surf);                                                           /* CGContextDrawImage puts the first row at the top of the destination (largest y) */
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef bc = CGBitmapContextCreate(surf.px, w, h, 8, surf.stride, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(cs);
	if (bc) { CGImageRef img = CGBitmapContextCreateImage(bc); if (img) { CGContextDrawImage(ctx, r, img); CGImageRelease(img); } CGContextRelease(bc); }
	RSurfFree(&surf);
}
void CARenderLayerTree(CALayer *l, CGContextRef ctx) { CADrawTree(l, ctx, YES); }
void CARenderPresentation(CALayer *root, CGContextRef ctx, CFTimeInterval time, BOOL applyTransform)
{
	CALayer *tree = [root _presentationTreeAtTime:time ?: CACurrentMediaTime()];
	CADrawTree(tree, ctx, !applyTransform);
}
void CALayerSetContextRoot(CALayer *root, BOOL isRoot) { [root _setContext:isRoot]; if (isRoot) [root _markCommitted]; }
BOOL CALayerTreeHasActiveAnimations(CALayer *root) { return [root _treeHasActiveAnimations:CACurrentMediaTime()]; }

@implementation CARenderer
{
	CALayer *_layer; CGRect _bounds; uint8_t *_data; size_t _w, _h, _stride; CFTimeInterval _frameTime;
}
+ (CARenderer *)rendererWithBitmap:(void *)data width:(size_t)w height:(size_t)h bytesPerRow:(size_t)rb options:(NSDictionary *)o
{
	CARenderer *r = [[self alloc] init]; r->_data = data; r->_w = w; r->_h = h; r->_stride = rb; r->_bounds = CGRectMake(0, 0, w, h); return r;
}
- (CALayer *)layer { return _layer; }
- (void)setLayer:(CALayer *)l { _layer = l; [l _setContext:YES]; }
- (CGRect)bounds { return _bounds; }
- (void)setBounds:(CGRect)b { _bounds = b; }
- (void)beginFrameAtTime:(CFTimeInterval)t timeStamp:(void *)ts { _frameTime = t; }
- (CGRect)updateBounds { return _bounds; }
- (void)addUpdateRect:(CGRect)r {}
- (void)render
{
	if (!_layer || !_data) return;
	CALayer *tree = [_layer _presentationTreeAtTime:_frameTime ?: CACurrentMediaTime()];
	RSurf dest; RSurfWrap(&dest, _data, (int)_w, (int)_h, (int)_stride);
	RCtx cx = { &dest, { 0, 0, (int)_w, (int)_h, NULL, 0 }, 0, 0 };
	RMat origin = RMatIdentity(); origin.m[12] = -_bounds.origin.x; origin.m[13] = -_bounds.origin.y;
	RenderLayerEx(tree, origin, &cx, NO);
}
- (CFTimeInterval)nextFrameTime { return INFINITY; }
- (void)endFrame {}
@end

