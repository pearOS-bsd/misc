/* CAKeyframeAnimation evaluation. */
#import "CALayerPrivate.h"

typedef enum { kModeDiscrete = 0, kModeLinear = 1, kModePaced = 2, kModeCubic = 3, kModeCubicPaced = 4 } KFMode;
static KFMode CAMode(NSString *s)
{
	if ([s isEqualToString:@"discrete"]) return kModeDiscrete;
	if ([s isEqualToString:@"paced"]) return kModePaced;
	if ([s isEqualToString:@"cubic"]) return kModeCubic;
	if ([s isEqualToString:@"cubicPaced"]) return kModeCubicPaced;
	return kModeLinear;
}

/* distances between consecutive values, for the paced modes: the key times are made proportional to them */
static double CADistance(id a, id b)
{
	if ([a isKindOfClass:[NSNumber class]]) return fabs([a doubleValue] - [b doubleValue]);
	if (a && b && CAIsColor(a) && CAIsColor(b)) {
		double x[4], y[4]; CAColorGetExtSRGB((__bridge CGColorRef)a, x); CAColorGetExtSRGB((__bridge CGColorRef)b, y);
		double s = 0; for (int i = 0; i < 4; i++) s += (x[i] - y[i]) * (x[i] - y[i]);
		return sqrt(s);
	}
	if (![a isKindOfClass:[NSValue class]]) return 1.0;
	if ([a isKindOfClass:[NSValue class]] && [b isKindOfClass:[NSValue class]]) {
		double x[16] = { 0 }, y[16] = { 0 }; [a getValue:x]; [b getValue:y]; size_t sz; NSGetSizeAndAlignment([a objCType], &sz, NULL);
		size_t c = sz / 8;
		if (c == 2 || c == 3) { double s = 0; for (size_t i = 0; i < c; i++) s += (x[i] - y[i]) * (x[i] - y[i]); return sqrt(s); }
		if (c == 1) return y[0];
	}
	return 0;
}

/* cubic modes: a Hermite spline through the values; the tangents come from the neighbours (Kochanek-Bartels, tension / continuity / bias 0 by default) */
static BOOL CAHermiteCapable(id v)
{
	if ([v isKindOfClass:[NSNumber class]]) return YES;
	if (v && CAIsColor(v)) return YES;
	if ([v isKindOfClass:[NSValue class]]) { const char *t = [v objCType]; return t && t[0] == '{' && !strstr(t, "Transform") && !strstr(t, "ColorMatrix"); }
	return NO;
}
static int CAComps(id v, double *out)
{
	if ([v isKindOfClass:[NSNumber class]]) { out[0] = [v doubleValue]; return 1; }
	if (CAIsColor(v)) { CAColorGetExtSRGB((__bridge CGColorRef)v, out); return 4; }
	size_t sz; NSGetSizeAndAlignment([v objCType], &sz, NULL); [v getValue:out]; return (int)(sz / 8);
}
static id CAHermite(NSArray *vals, double *kt, NSUInteger i, double u, NSArray *tens, NSArray *cont, NSArray *bias)
{
	NSUInteger n = vals.count;
	double p[4][16]; int nc = 0;
	for (int s = 0; s < 4; s++) { NSInteger j = (NSInteger)i + s - 1; if (j < 0) j = 0; if (j >= (NSInteger)n) j = n - 1; nc = CAComps(vals[(NSUInteger)j], p[s]); }
	double out[16]; double h = kt[i + 1] - kt[i];
	double m[2][16];
	for (int side = 0; side < 2; side++) {
		NSUInteger idx = i + side;
		double T = idx < tens.count ? [tens[idx] doubleValue] : 0, C = idx < cont.count ? [cont[idx] doubleValue] : 0, B = idx < bias.count ? [bias[idx] doubleValue] : 0;
		double pv[16], pc[16], pn[16]; CAComps(vals[idx], pc);
		BOOL hasPrev = idx > 0, hasNext = idx + 1 < n; double kp = hasPrev ? kt[idx] - kt[idx - 1] : 0, kn = hasNext ? kt[idx + 1] - kt[idx] : 0;
		if (hasPrev) CAComps(vals[idx - 1], pv); if (hasNext) CAComps(vals[idx + 1], pn);
		for (int c = 0; c < nc; c++) {
			double dp = hasPrev ? (pc[c] - pv[c]) / kp : 0, dn = hasNext ? (pn[c] - pc[c]) / kn : 0, mm;
			if (!hasPrev) mm = (1 - T) * dn; else if (!hasNext) mm = (1 - T) * dp;
			else {
				double wp = kp / (kp + kn), wn = kn / (kp + kn);
				mm = side == 0 ? (1 - T) * ((1 + B) * (1 + C) * wp * dp + (1 - B) * (1 - C) * wn * dn) : (1 - T) * ((1 + B) * (1 - C) * wp * dp + (1 - B) * (1 + C) * wn * dn);
				/* the outgoing tangent belongs to the start of the segment (side 0), the incoming one to its end */
			}
			m[side][c] = mm * h;
		}
	}
	if (u == 0 && ![vals[0] isKindOfClass:[NSNumber class]]) return vals[i];
	if (u == 1 && ![vals[0] isKindOfClass:[NSNumber class]]) return vals[i + 1];
	double h00 = 2 * u * u * u - 3 * u * u + 1, h10 = u * u * u - 2 * u * u + u, h01 = -2 * u * u * u + 3 * u * u, h11 = u * u * u - u * u;
	for (int c = 0; c < nc; c++) out[c] = h00 * p[1][c] + h10 * m[0][c] + h01 * p[2][c] + h11 * m[1][c];
	if ([vals[0] isKindOfClass:[NSNumber class]]) return @(out[0]);
	if (CAIsColor(vals[0])) return CFBridgingRelease(CAColorCreateExtSRGB(out));
	return [NSValue valueWithBytes:out objCType:[vals[0] objCType]];
}

typedef struct { int kind; CGPoint p[4]; } CAPathSeg;               /* kind 1 line, 2 quad, 3 cubic; p[0] is the start */
typedef struct { CAPathSeg seg[512]; int n; CGPoint cur, start; } CAPathSegs;
static void CAPathCollect(void *info, const CGPathElement *e)
{
	CAPathSegs *s = info; CAPathSeg *g = s->n < 512 ? &s->seg[s->n] : NULL;
	switch (e->type) {
	case kCGPathElementMoveToPoint: s->cur = s->start = e->points[0]; return;
	case kCGPathElementAddLineToPoint: if (g) { g->kind = 1; g->p[0] = s->cur; g->p[1] = e->points[0]; s->n++; } s->cur = e->points[0]; return;
	case kCGPathElementAddQuadCurveToPoint: if (g) { g->kind = 2; g->p[0] = s->cur; g->p[1] = e->points[0]; g->p[2] = e->points[1]; s->n++; } s->cur = e->points[1]; return;
	case kCGPathElementAddCurveToPoint: if (g) { g->kind = 3; g->p[0] = s->cur; g->p[1] = e->points[0]; g->p[2] = e->points[1]; g->p[3] = e->points[2]; s->n++; } s->cur = e->points[2]; return;
	case kCGPathElementCloseSubpath: if (g) { g->kind = 1; g->p[0] = s->cur; g->p[1] = s->start; s->n++; } s->cur = s->start; return;
	}
}
static void CAPathEvalPoint(const CAPathSeg *g, double u, CGPoint *pt, CGPoint *tan);
#define CALENSTEPS 256
static double CAPathSegLength(const CAPathSeg *g, double *table)      /* table[i] = length up to u = i / CALENSTEPS */
{
	CGPoint prev = g->p[0], pt, tg; double L = 0;
	if (table) table[0] = 0;
	for (int i = 1; i <= CALENSTEPS; i++) {
		CAPathEvalPoint(g, (double)i / CALENSTEPS, &pt, &tg);
		L += hypot(pt.x - prev.x, pt.y - prev.y); prev = pt;
		if (table) table[i] = L;
	}
	return L;
}
/* the parameter at which the arc length of the segment is s */
static double CAPathParamAtLength(const double *table, double s)
{
	int lo = 0, hi = CALENSTEPS;
	while (hi - lo > 1) { int mid = (lo + hi) / 2; if (table[mid] <= s) lo = mid; else hi = mid; }
	double span = table[hi] - table[lo], f = span > 0 ? (s - table[lo]) / span : 0;
	return ((double)lo + f) / CALENSTEPS;
}
/* the point and the tangent of a segment at u (0 ... 1) */
static void CAPathEvalPoint(const CAPathSeg *g, double u, CGPoint *pt, CGPoint *tan);
static void CAPathEval(const CAPathSeg *g, double u, CGPoint *pt, CGPoint *tan) { CAPathEvalPoint(g, u, pt, tan); }
static void CAPathEvalPoint(const CAPathSeg *g, double u, CGPoint *pt, CGPoint *tan)
{
	double v = 1 - u;
	if (g->kind == 1) {
		pt->x = g->p[0].x + (g->p[1].x - g->p[0].x) * u; pt->y = g->p[0].y + (g->p[1].y - g->p[0].y) * u;
		tan->x = g->p[1].x - g->p[0].x; tan->y = g->p[1].y - g->p[0].y;
	} else if (g->kind == 2) {
		pt->x = v * v * g->p[0].x + 2 * v * u * g->p[1].x + u * u * g->p[2].x; pt->y = v * v * g->p[0].y + 2 * v * u * g->p[1].y + u * u * g->p[2].y;
		tan->x = 2 * v * (g->p[1].x - g->p[0].x) + 2 * u * (g->p[2].x - g->p[1].x); tan->y = 2 * v * (g->p[1].y - g->p[0].y) + 2 * u * (g->p[2].y - g->p[1].y);
	} else {
		pt->x = v * v * v * g->p[0].x + 3 * v * v * u * g->p[1].x + 3 * v * u * u * g->p[2].x + u * u * u * g->p[3].x;
		pt->y = v * v * v * g->p[0].y + 3 * v * v * u * g->p[1].y + 3 * v * u * u * g->p[2].y + u * u * u * g->p[3].y;
		tan->x = 3 * (v * v * (g->p[1].x - g->p[0].x) + 2 * v * u * (g->p[2].x - g->p[1].x) + u * u * (g->p[3].x - g->p[2].x));
		tan->y = 3 * (v * v * (g->p[1].y - g->p[0].y) + 2 * v * u * (g->p[2].y - g->p[1].y) + u * u * (g->p[3].y - g->p[2].y));
	}
}

void CAKeyframeApply(CAKeyframeAnimation *k, CFTimeInterval time, id pres, id model)
{
	if (![k isEnabled]) return;
	NSString *kp = [k keyPath]; if (!kp) return;
	double t = time; int iteration = 0;
	CATiming tm; BOOL has = CAAnimationTiming(k, &tm);
	if (has) {
		if (!CATimingMapParentToActive(&tm, &t, NULL)) return;
		double cycle = tm.autoreverses ? tm.duration + tm.duration : tm.duration;
		iteration = fabs(cycle) <= DBL_MAX ? (int)floor(t / cycle) : 0;
		CATimingMapActiveToLocal(&tm, &t, NULL);
		t = t / tm.duration;
	}
	if ([k timingFunction]) t = (double)[[k timingFunction] _solve:(float)t];
	KFMode mode = CAMode([k calculationMode]);
	NSArray *values = [k values];
	CGPathRef path = [k path];
	CAPathSegs ps = { 0 };
	if (path) {
		CGPathApply(path, &ps, CAPathCollect);
		if (ps.n < 1) return;
		/* the key frames of a path animation are its segments: n segments have n + 1 key points */
		NSMutableArray *pv = [NSMutableArray array];
		for (int i = 0; i <= ps.n; i++) [pv addObject:[NSValue valueWithPoint:NSMakePoint(i == 0 ? ps.seg[0].p[0].x : ps.seg[i - 1].p[ps.seg[i - 1].kind == 1 ? 1 : (ps.seg[i - 1].kind == 2 ? 2 : 3)].x, i == 0 ? ps.seg[0].p[0].y : ps.seg[i - 1].p[ps.seg[i - 1].kind == 1 ? 1 : (ps.seg[i - 1].kind == 2 ? 2 : 3)].y)]];
		values = pv;
	}
	NSUInteger n = values.count; if (n < 1) return;
	NSArray *keyTimes = [k keyTimes];
	double kt[n + 1];
	if (mode == kModePaced || mode == kModeCubicPaced) {
		double total = 0, dist[n]; dist[0] = 0;
		for (NSUInteger i = 1; i < n; i++) { dist[i] = CADistance(values[i - 1], values[i]); total += dist[i]; }
		if (path) { total = 0; for (int i = 0; i < ps.n; i++) { dist[i + 1] = CAPathSegLength(&ps.seg[i], NULL); total += dist[i + 1]; } }
		double acc = 0, inv = 1.0 / total; kt[0] = 0;
		for (NSUInteger i = 1; i < n; i++) { acc += dist[i]; kt[i] = acc * inv; }
	} else if (keyTimes.count == n) for (NSUInteger i = 0; i < n; i++) kt[i] = [keyTimes[i] doubleValue];
	else if (mode == kModeDiscrete) for (NSUInteger i = 0; i < n; i++) kt[i] = (double)i / n;
	else for (NSUInteger i = 0; i < n; i++) kt[i] = n > 1 ? (double)i / (n - 1) : 0;
	id value;
	BOOL onPath = path != NULL;
	BOOL cubic = (mode == kModeCubic || mode == kModeCubicPaced) && n > 2 && CAHermiteCapable(values[0]);
	if (onPath) {
		NSUInteger i = 0; while (i + 2 < n && kt[i + 1] <= t) i++;
		double span = kt[i + 1] - kt[i], u = (t - kt[i]) / span;
		u = u > 1 ? 1 : (u < 0 ? 0 : u);
		NSArray *tfs = [k timingFunctions]; if (tfs && i < tfs.count && mode != kModePaced && mode != kModeCubicPaced) u = (double)[tfs[i] _solve:(float)u];
		if (mode == kModePaced || mode == kModeCubicPaced) { double tab[CALENSTEPS + 1]; double L = CAPathSegLength(&ps.seg[i], tab); u = CAPathParamAtLength(tab, u * L); }
		CGPoint pt, tan; CAPathEval(&ps.seg[i], u, &pt, &tan);
		value = [NSValue valueWithPoint:NSMakePoint(pt.x, pt.y)];
		NSString *rm = [k rotationMode];
		if (rm) { double ang = atan2(tan.y, tan.x) + ([rm isEqualToString:@"autoReverse"] ? M_PI : 0); [pres setValue:[NSValue valueWithCATransform3D:CATransform3DMakeRotation(ang, 0, 0, 1)] forKeyPath:@"transform"]; }
	}
	else if (n == 1) value = values[0];
	else if (cubic) {
		NSUInteger i = 0; while (i + 2 < n && kt[i + 1] <= t) i++;
		double span = kt[i + 1] - kt[i], u = (t - kt[i]) / span;
		u = u > 1 ? 1 : (u < 0 ? 0 : u);
		value = CAHermite(values, kt, i, u, [k tensionValues], [k continuityValues], [k biasValues]);
	}
	else if (mode == kModeDiscrete) {
		NSUInteger i = 0; for (NSUInteger j = 0; j < n; j++) if (kt[j] <= t) i = j;
		value = values[i];
	} else {
		NSUInteger i = 0; while (i + 2 < n && kt[i + 1] <= t) i++;
		double span = kt[i + 1] - kt[i], lt = (t - kt[i]) / span;
		lt = lt > 1 ? 1 : (lt < 0 ? 0 : lt);
		NSArray *tfs = [k timingFunctions];
		if (tfs && i < tfs.count && mode != kModePaced && mode != kModeCubicPaced) lt = (double)[tfs[i] _solve:(float)lt];
		value = lt == 0 ? values[i] : (lt == 1 ? values[i + 1] : CAValueInterpolate(values[i], values[i + 1], (float)lt));
	}
	if ([k isCumulative] && iteration) value = CAValueAdd(value, values.lastObject, iteration);
	if ([k valueFunction]) value = CAValueApplyFunction([k valueFunction], value, k, pres);
	if ([k isAdditive]) value = CAValueAdd([pres valueForKeyPath:kp], value, 1);
	[pres setValue:value forKeyPath:kp];
}
