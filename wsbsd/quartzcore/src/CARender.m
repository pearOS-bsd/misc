/* The layer compositor: renders a presentation tree with the software rasterizer. */
#import "CALayerPrivate.h"
#include "CARaster.h"

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
	if (!contents || CFGetTypeID((__bridge CFTypeRef)contents) != CGImageGetTypeID()) return nil;
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

static void RenderLayer(CALayer *l, RMat parent, RCtx *cx);

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

static void RenderContent(CALayer *l, RMat M, RCtx *cx, float opacity)
{
	CGRect b = [l bounds];
	RShape shape = ShapeFor(l, b);
	CGColorRef bg = [l backgroundColor];
	if (bg) RFillShape(cx->dest, &cx->clip, M, &shape, CAPremulColor(bg, opacity), 0);
	DrawContents(l, M, cx, b, (HasRadius(&shape) || [l masksToBounds]) ? &shape : NULL, opacity);
	NSArray *subs = [l _sublayerArray];
	RCtx sub = *cx; uint8_t *buf = NULL;
	if ([l masksToBounds]) PushShapeClip(cx, M, &shape, &sub, &buf);
	for (CALayer *s in subs) RenderLayer(s, M, &sub);
	free(buf);
	double bw = [l borderWidth];
	if (bw > 0) RStrokeShape(cx->dest, &cx->clip, M, &shape, bw, CAPremulColor([l borderColor], opacity));
}

static BOOL NeedsGroup(CALayer *l)
{
	float op = [l opacity];
	if (op < 1 && [l allowsGroupOpacity] && ([[l _sublayerArray] count] || ([l borderWidth] > 0 && ([l backgroundColor] || [l contents])))) return YES;
	if ([l shadowOpacity] > 0 || [l mask]) return YES;
	return NO;
}

static void ExtentOf(CALayer *l, RMat parent, double *minx, double *miny, double *maxx, double *maxy, int depth)
{
	RMat M = RMatMul(RM([l _localToSuperMatrix]), parent);
	CGRect b = [l bounds]; double xs[4] = { b.origin.x, b.origin.x + b.size.width, b.origin.x, b.origin.x + b.size.width }, ys[4] = { b.origin.y, b.origin.y, b.origin.y + b.size.height, b.origin.y + b.size.height };
	for (int i = 0; i < 4; i++) {
		double a = xs[i] * M.m[0] + ys[i] * M.m[4] + M.m[12], c = xs[i] * M.m[1] + ys[i] * M.m[5] + M.m[13], w = xs[i] * M.m[3] + ys[i] * M.m[7] + M.m[15];
		if (w <= 1e-6) { *minx = -1e9; *miny = -1e9; *maxx = 1e9; *maxy = 1e9; return; }
		a /= w; c /= w; if (a < *minx) *minx = a; if (a > *maxx) *maxx = a; if (c < *miny) *miny = c; if (c > *maxy) *maxy = c;
	}
	if (![l masksToBounds] && depth < 32) for (CALayer *s in [l _sublayerArray]) ExtentOf(s, M, minx, miny, maxx, maxy, depth + 1);
}

/* renders one layer (and its sublayers); `parent` maps the coordinates of the superlayer's content to the surface */
static void RenderLayer(CALayer *l, RMat parent, RCtx *cx)
{
	if ([l isHidden]) return;
	float opacity = [l opacity]; if (opacity <= 0) return;
	RMat M = RMatMul(RM([l _localToSuperMatrix]), parent);
	CGRect b = [l bounds];
	if ((b.size.width <= 0 || b.size.height <= 0) && ![[l _sublayerArray] count]) return;
	if (![l isDoubleSided]) {
		/* a layer seen from behind is not drawn: the orientation of its projected plane */
		double det = M.m[0] * M.m[5] - M.m[1] * M.m[4]; if (det < 0 && M.m[3] == 0 && M.m[7] == 0) return;
	}
	if (!NeedsGroup(l)) { RenderContent(l, M, cx, opacity); return; }
	/* a group: the layer and its sublayers are drawn together, then shadow, mask and opacity are applied */
	double minx = 1e30, miny = 1e30, maxx = -1e30, maxy = -1e30;
	ExtentOf(l, parent, &minx, &miny, &maxx, &maxy, 0);
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

void CARenderLayerTree(CALayer *l, CGContextRef ctx) {}

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
	RenderLayer(tree, origin, &cx);
}
- (CFTimeInterval)nextFrameTime { return INFINITY; }
- (void)endFrame {}
@end
