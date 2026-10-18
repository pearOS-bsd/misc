/* The software rasterizer of the layer compositor (see CARaster.h). */
#include "CARaster.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

RSurf RSurfCreate(int w, int h)
{
	RSurf s = { w, h, w * 4, NULL, 1 };
	s.px = calloc((size_t)(w > 0 ? w : 1) * (h > 0 ? h : 1), 4);
	return s;
}
void RSurfFree(RSurf *s) { if (s->owns) free(s->px); s->px = NULL; }
void RSurfClear(RSurf *s) { for (int y = 0; y < s->h; y++) memset(s->px + (size_t)y * s->stride, 0, (size_t)s->w * 4); }
void RSurfWrap(RSurf *s, uint8_t *px, int w, int h, int stride) { s->w = w; s->h = h; s->stride = stride; s->px = px; s->owns = 0; }

RMat RMatIdentity(void) { RMat r = { { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 } }; return r; }
RMat RMatMul(RMat a, RMat b)
{
	RMat r;
	for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++)
		r.m[i * 4 + j] = a.m[i * 4] * b.m[j] + a.m[i * 4 + 1] * b.m[4 + j] + a.m[i * 4 + 2] * b.m[8 + j] + a.m[i * 4 + 3] * b.m[12 + j];
	return r;
}
RMat RMatInvert(RMat a, int *ok)
{
	const double *m = a.m; RMat r = RMatIdentity();
	double s0 = m[0] * m[5] - m[4] * m[1], s1 = m[0] * m[6] - m[4] * m[2], s2 = m[0] * m[7] - m[4] * m[3], s3 = m[1] * m[6] - m[5] * m[2], s4 = m[1] * m[7] - m[5] * m[3], s5 = m[2] * m[7] - m[6] * m[3];
	double c5 = m[10] * m[15] - m[14] * m[11], c4 = m[9] * m[15] - m[13] * m[11], c3 = m[9] * m[14] - m[13] * m[10], c2 = m[8] * m[15] - m[12] * m[11], c1 = m[8] * m[14] - m[12] * m[10], c0 = m[8] * m[13] - m[12] * m[9];
	double det = s0 * c5 - s1 * c4 + s2 * c3 + s3 * c2 - s4 * c1 + s5 * c0;
	if (ok) *ok = det != 0 && isfinite(det);
	if (det == 0 || !isfinite(det)) return r;
	double id = 1.0 / det; double *o = r.m;
	o[0] = (m[5] * c5 - m[6] * c4 + m[7] * c3) * id;   o[1] = (-m[1] * c5 + m[2] * c4 - m[3] * c3) * id;   o[2] = (m[13] * s5 - m[14] * s4 + m[15] * s3) * id;   o[3] = (-m[9] * s5 + m[10] * s4 - m[11] * s3) * id;
	o[4] = (-m[4] * c5 + m[6] * c2 - m[7] * c1) * id;  o[5] = (m[0] * c5 - m[2] * c2 + m[3] * c1) * id;    o[6] = (-m[12] * s5 + m[14] * s2 - m[15] * s1) * id;  o[7] = (m[8] * s5 - m[10] * s2 + m[11] * s1) * id;
	o[8] = (m[4] * c4 - m[5] * c2 + m[7] * c0) * id;   o[9] = (-m[0] * c4 + m[1] * c2 - m[3] * c0) * id;   o[10] = (m[12] * s4 - m[13] * s2 + m[15] * s0) * id;  o[11] = (-m[8] * s4 + m[9] * s2 - m[11] * s0) * id;
	o[12] = (-m[4] * c3 + m[5] * c1 - m[6] * c0) * id; o[13] = (m[0] * c3 - m[1] * c1 + m[2] * c0) * id;   o[14] = (-m[12] * s3 + m[13] * s1 - m[14] * s0) * id; o[15] = (m[8] * s3 - m[9] * s1 + m[10] * s0) * id;
	return r;
}

/* ---- the 2D homography of a layer plane ------------------------------------------------------------------------------------------------------------------ */
typedef struct { double h[9]; double inv[9]; int ok; int affine; } Homog;       /* [x y 1] * h = [X Y W] */
static Homog MakeHomog(RMat m)
{
	Homog H;
	const double *a = m.m;
	double h[9] = { a[0], a[1], a[3], a[4], a[5], a[7], a[12], a[13], a[15] };
	memcpy(H.h, h, sizeof h);
	double det = h[0] * (h[4] * h[8] - h[5] * h[7]) - h[1] * (h[3] * h[8] - h[5] * h[6]) + h[2] * (h[3] * h[7] - h[4] * h[6]);
	H.ok = fabs(det) > 1e-18 && isfinite(det);
	H.affine = h[2] == 0 && h[5] == 0 && h[8] == 1;
	if (H.ok) {
		double id = 1.0 / det;
		H.inv[0] = (h[4] * h[8] - h[5] * h[7]) * id; H.inv[1] = (h[2] * h[7] - h[1] * h[8]) * id; H.inv[2] = (h[1] * h[5] - h[2] * h[4]) * id;
		H.inv[3] = (h[5] * h[6] - h[3] * h[8]) * id; H.inv[4] = (h[0] * h[8] - h[2] * h[6]) * id; H.inv[5] = (h[2] * h[3] - h[0] * h[5]) * id;
		H.inv[6] = (h[3] * h[7] - h[4] * h[6]) * id; H.inv[7] = (h[1] * h[6] - h[0] * h[7]) * id; H.inv[8] = (h[0] * h[4] - h[1] * h[3]) * id;
	}
	return H;
}
static int Project(const Homog *H, double x, double y, double *X, double *Y)
{
	double a = x * H->h[0] + y * H->h[3] + H->h[6], b = x * H->h[1] + y * H->h[4] + H->h[7], w = x * H->h[2] + y * H->h[5] + H->h[8];
	if (w <= 1e-9) return 0;
	*X = a / w; *Y = b / w; return 1;
}
static void Unproject(const Homog *H, double px, double py, double *x, double *y, double *w)
{
	double a = px * H->inv[0] + py * H->inv[3] + H->inv[6], b = px * H->inv[1] + py * H->inv[4] + H->inv[7], ww = px * H->inv[2] + py * H->inv[5] + H->inv[8];
	*w = ww; *x = a / ww; *y = b / ww;
}
/* bounding box of a rectangle projected; returns 0 when it is not visible (behind the eye) */
static int ProjectBounds(const Homog *H, RRect r, int *x0, int *y0, int *x1, int *y1, const RSurf *s)
{
	double xs[4] = { r.x, r.x + r.w, r.x, r.x + r.w }, ys[4] = { r.y, r.y, r.y + r.h, r.y + r.h };
	double minx = 1e30, miny = 1e30, maxx = -1e30, maxy = -1e30; int vis = 0;
	for (int i = 0; i < 4; i++) { double X, Y; if (!Project(H, xs[i], ys[i], &X, &Y)) { vis = -1; break; } minx = fmin(minx, X); maxx = fmax(maxx, X); miny = fmin(miny, Y); maxy = fmax(maxy, Y); }
	if (vis < 0) { minx = 0; miny = 0; maxx = s->w; maxy = s->h; }                    /* a corner behind the eye: the whole surface is scanned */
	*x0 = (int)floor(minx) - 1; *y0 = (int)floor(miny) - 1; *x1 = (int)ceil(maxx) + 1; *y1 = (int)ceil(maxy) + 1;
	if (*x0 < 0) *x0 = 0; if (*y0 < 0) *y0 = 0; if (*x1 > s->w) *x1 = s->w; if (*y1 > s->h) *y1 = s->h;
	return *x1 > *x0 && *y1 > *y0;
}

/* ---- shapes ---------------------------------------------------------------------------------------------------------------------------------------------------------- */
/* signed distance (negative inside) from the point to the rounded rectangle, in layer units */
static double ShapeSD(const RShape *s, double x, double y)
{
	double cx = s->r.x + s->r.w * 0.5, cy = s->r.y + s->r.h * 0.5, hx = s->r.w * 0.5, hy = s->r.h * 0.5;
	double dx = x - cx, dy = y - cy;
	double rad = dx < 0 ? (dy < 0 ? s->rad[0] : s->rad[3]) : (dy < 0 ? s->rad[1] : s->rad[2]);
	if (s->continuous) rad *= 1.528665;                                    /* the continuous curve reaches further along the sides */
	double lim = hx < hy ? hx : hy; if (rad > lim) rad = lim;
	double qx = fabs(dx) - (hx - rad), qy = fabs(dy) - (hy - rad);
	if (rad <= 0) return fmax(qx, qy);
	if (s->continuous && qx > 0 && qy > 0) {
		static double n = 0; if (n == 0) { const char *e = getenv("CA_CN"); n = e ? atof(e) : 3.5; }
		double a = pow(pow(qx / rad, n) + pow(qy / rad, n), 1.0 / n); return (a - 1) * rad;
	}
	double ox = qx > 0 ? qx : 0, oy = qy > 0 ? qy : 0;
	return sqrt(ox * ox + oy * oy) + fmin(fmax(qx, qy), 0) - rad;
}
static inline float CovFromSD(double sd, double pixelScale) { double c = 0.5 - sd * pixelScale; return c <= 0 ? 0 : (c >= 1 ? 1 : (float)c); }

static inline float ClipCoverage(const RClip *c, int x, int y)
{
	if (!c) return 1;
	if (x < c->x0 || x >= c->x1 || y < c->y0 || y >= c->y1) return 0;
	if (c->mask) return c->mask[(size_t)y * c->mstride + x] * (1.0f / 255);
	return 1;
}
static inline void Blend(uint8_t *d, float r, float g, float b, float a)
{
	/* r g b are premultiplied, already scaled by the coverage */
	float ia = 1.0f - a;
	float nb = b * 255 + d[0] * ia, ng = g * 255 + d[1] * ia, nr = r * 255 + d[2] * ia, na = a * 255 + d[3] * ia;
	d[0] = (uint8_t)(nb > 255 ? 255 : nb + 0.5f); d[1] = (uint8_t)(ng > 255 ? 255 : ng + 0.5f); d[2] = (uint8_t)(nr > 255 ? 255 : nr + 0.5f); d[3] = (uint8_t)(na > 255 ? 255 : na + 0.5f);
}

/* the scale from layer units to pixels at a point (for the antialiasing width) */
static double LocalScale(const Homog *H, double x, double y)
{
	if (H->affine) return sqrt(fabs(H->h[0] * H->h[4] - H->h[1] * H->h[3]));
	double X0, Y0, X1, Y1, X2, Y2;
	if (!Project(H, x, y, &X0, &Y0) || !Project(H, x + 1, y, &X1, &Y1) || !Project(H, x, y + 1, &X2, &Y2)) return 1;
	return sqrt(fabs((X1 - X0) * (Y2 - Y0) - (Y1 - Y0) * (X2 - X0)));
}

void RFillShape(RSurf *dest, const RClip *clip, RMat m, const RShape *shape, RColor c, int backface)
{
	Homog H = MakeHomog(m); if (!H.ok) return;
	int x0, y0, x1, y1;
	if (!ProjectBounds(&H, shape->r, &x0, &y0, &x1, &y1, dest)) return;
	if (clip) { if (x0 < clip->x0) x0 = clip->x0; if (y0 < clip->y0) y0 = clip->y0; if (x1 > clip->x1) x1 = clip->x1; if (y1 > clip->y1) y1 = clip->y1; }
	double sc = LocalScale(&H, shape->r.x + shape->r.w / 2, shape->r.y + shape->r.h / 2);
	(void)backface;
	for (int y = y0; y < y1; y++) {
		uint8_t *row = dest->px + (size_t)y * dest->stride;
		for (int x = x0; x < x1; x++) {
			double lx, ly, w; Unproject(&H, x + 0.5, y + 0.5, &lx, &ly, &w);
			if (w <= 0) continue;
			double psc = H.affine ? sc : LocalScale(&H, lx, ly);
			float cov = CovFromSD(ShapeSD(shape, lx, ly), psc);
			if (cov <= 0) continue;
			cov *= ClipCoverage(clip, x, y);
			if (cov <= 0) continue;
			Blend(row + x * 4, c.r * cov, c.g * cov, c.b * cov, c.a * cov);
		}
	}
}

void RStrokeShape(RSurf *dest, const RClip *clip, RMat m, const RShape *shape, double bw, RColor c)
{
	Homog H = MakeHomog(m); if (!H.ok) return;
	RShape inner = *shape; inner.r.x += bw; inner.r.y += bw; inner.r.w -= 2 * bw; inner.r.h -= 2 * bw;
	for (int i = 0; i < 4; i++) { inner.rad[i] = shape->rad[i] - bw; if (inner.rad[i] < 0) inner.rad[i] = 0; }
	int x0, y0, x1, y1;
	if (!ProjectBounds(&H, shape->r, &x0, &y0, &x1, &y1, dest)) return;
	if (clip) { if (x0 < clip->x0) x0 = clip->x0; if (y0 < clip->y0) y0 = clip->y0; if (x1 > clip->x1) x1 = clip->x1; if (y1 > clip->y1) y1 = clip->y1; }
	double sc = LocalScale(&H, shape->r.x + shape->r.w / 2, shape->r.y + shape->r.h / 2);
	int hasInner = inner.r.w > 0 && inner.r.h > 0;
	for (int y = y0; y < y1; y++) {
		uint8_t *row = dest->px + (size_t)y * dest->stride;
		for (int x = x0; x < x1; x++) {
			double lx, ly, w; Unproject(&H, x + 0.5, y + 0.5, &lx, &ly, &w);
			if (w <= 0) continue;
			double psc = H.affine ? sc : LocalScale(&H, lx, ly);
			float co = CovFromSD(ShapeSD(shape, lx, ly), psc);
			if (co <= 0) continue;
			float ci = hasInner ? CovFromSD(ShapeSD(&inner, lx, ly), psc) : 0;
			float cov = co * (1 - ci);
			if (cov <= 0) continue;
			cov *= ClipCoverage(clip, x, y);
			if (cov <= 0) continue;
			Blend(row + x * 4, c.r * cov, c.g * cov, c.b * cov, c.a * cov);
		}
	}
}

/* ---- images ---------------------------------------------------------------------------------------------------------------------------------------------------------- */
static inline void Texel(const RSurf *t, int x, int y, float *o)
{
	if (x < 0) x = 0; if (y < 0) y = 0; if (x >= t->w) x = t->w - 1; if (y >= t->h) y = t->h - 1;
	const uint8_t *p = t->px + (size_t)y * t->stride + x * 4;
	o[0] = p[2] * (1.0f / 255); o[1] = p[1] * (1.0f / 255); o[2] = p[0] * (1.0f / 255); o[3] = p[3] * (1.0f / 255);
}
void RDrawImage(RSurf *dest, const RClip *clip, RMat m, const RSurf *img, RRect src, RRect dst, const RShape *region, float opacity, int nearest)
{
	Homog H = MakeHomog(m); if (!H.ok || dst.w <= 0 || dst.h <= 0) return;
	int x0, y0, x1, y1;
	if (!ProjectBounds(&H, dst, &x0, &y0, &x1, &y1, dest)) return;
	if (clip) { if (x0 < clip->x0) x0 = clip->x0; if (y0 < clip->y0) y0 = clip->y0; if (x1 > clip->x1) x1 = clip->x1; if (y1 > clip->y1) y1 = clip->y1; }
	RShape rectShape = { dst, { 0, 0, 0, 0 }, 0 };
	double sc = LocalScale(&H, dst.x + dst.w / 2, dst.y + dst.h / 2);
	for (int y = y0; y < y1; y++) {
		uint8_t *row = dest->px + (size_t)y * dest->stride;
		for (int x = x0; x < x1; x++) {
			double lx, ly, w; Unproject(&H, x + 0.5, y + 0.5, &lx, &ly, &w);
			if (w <= 0) continue;
			double psc = H.affine ? sc : LocalScale(&H, lx, ly);
			float cov = CovFromSD(ShapeSD(&rectShape, lx, ly), psc);
			if (cov <= 0) continue;
			if (region) { cov *= CovFromSD(ShapeSD(region, lx, ly), psc); if (cov <= 0) continue; }
			cov *= ClipCoverage(clip, x, y) * opacity;
			if (cov <= 0) continue;
			double u = src.x + (lx - dst.x) / dst.w * src.w, v = src.y + (ly - dst.y) / dst.h * src.h;
			float t[4];
			if (nearest) Texel(img, (int)floor(u), (int)floor(v), t);
			else {
				double fu = u - 0.5, fv = v - 0.5; int iu = (int)floor(fu), iv = (int)floor(fv); float a = (float)(fu - iu), b = (float)(fv - iv);
				float t00[4], t10[4], t01[4], t11[4]; Texel(img, iu, iv, t00); Texel(img, iu + 1, iv, t10); Texel(img, iu, iv + 1, t01); Texel(img, iu + 1, iv + 1, t11);
				for (int k = 0; k < 4; k++) t[k] = (t00[k] * (1 - a) + t10[k] * a) * (1 - b) + (t01[k] * (1 - a) + t11[k] * a) * b;
			}
			Blend(row + x * 4, t[0] * cov, t[1] * cov, t[2] * cov, t[3] * cov);
		}
	}
}

void RComposite(RSurf *dest, const RSurf *src, int sx, int sy, float alpha, const RClip *clip)
{
	for (int y = 0; y < src->h; y++) {
		int dy = y + sy; if (dy < 0 || dy >= dest->h) continue;
		const uint8_t *s = src->px + (size_t)y * src->stride; uint8_t *d = dest->px + (size_t)dy * dest->stride;
		for (int x = 0; x < src->w; x++) {
			int dx = x + sx; if (dx < 0 || dx >= dest->w) continue;
			const uint8_t *p = s + x * 4; if (!p[3] && !p[0] && !p[1] && !p[2]) continue;
			float k = alpha * ClipCoverage(clip, dx, dy); if (k <= 0) continue;
			Blend(d + dx * 4, p[2] * (1.0f / 255) * k, p[1] * (1.0f / 255) * k, p[0] * (1.0f / 255) * k, p[3] * (1.0f / 255) * k);
		}
	}
}

/* ---- blur ------------------------------------------------------------------------------------------------------------------------------------------------------------- */
static void BoxBlurH(float *src, float *dst, int w, int h, int r)
{
	float k = 1.0f / (2 * r + 1);
	for (int y = 0; y < h; y++) {
		const float *s = src + (size_t)y * w; float *d = dst + (size_t)y * w; float acc = 0;
		for (int x = -r; x <= r; x++) acc += (x >= 0 && x < w) ? s[x] : 0;
		for (int x = 0; x < w; x++) { d[x] = acc * k; int add = x + r + 1, sub = x - r; acc += (add < w ? s[add] : 0) - (sub >= 0 ? s[sub] : 0); }
	}
}
static void BoxBlurV(float *src, float *dst, int w, int h, int r)
{
	float k = 1.0f / (2 * r + 1);
	for (int x = 0; x < w; x++) {
		float acc = 0;
		for (int y = -r; y <= r; y++) acc += (y >= 0 && y < h) ? src[(size_t)y * w + x] : 0;
		for (int y = 0; y < h; y++) { dst[(size_t)y * w + x] = acc * k; int add = y + r + 1, sub = y - r; acc += (add < h ? src[(size_t)add * w + x] : 0) - (sub >= 0 ? src[(size_t)sub * w + x] : 0); }
	}
}
/* three box blurs approximate a gaussian (box widths from the standard deviation) */
static void GaussianFloat(float *a, int w, int h, double sigma)
{
	if (sigma < 0.3) return;
	double wi = sqrt(12.0 * sigma * sigma / 3 + 1); int wl = (int)floor(wi); if (wl % 2 == 0) wl--; int wu = wl + 2;
	double mi = (12.0 * sigma * sigma - 3.0 * wl * wl - 4.0 * 3 * wl - 3.0 * 3) / (-4.0 * wl - 4);
	int m = (int)floor(mi + 0.5);
	float *tmp = malloc((size_t)w * h * sizeof(float));
	for (int i = 0; i < 3; i++) {
		int r = ((i < m ? wl : wu) - 1) / 2; if (r < 1) r = 1;
		BoxBlurH(a, tmp, w, h, r); BoxBlurV(tmp, a, w, h, r);
	}
	free(tmp);
}
void RBlur(RSurf *s, double sigma)
{
	float *c[4]; size_t n = (size_t)s->w * s->h;
	for (int k = 0; k < 4; k++) { c[k] = malloc(n * sizeof(float)); for (int y = 0; y < s->h; y++) for (int x = 0; x < s->w; x++) c[k][(size_t)y * s->w + x] = s->px[(size_t)y * s->stride + x * 4 + k] * (1.0f / 255); GaussianFloat(c[k], s->w, s->h, sigma); }
	for (int y = 0; y < s->h; y++) for (int x = 0; x < s->w; x++) for (int k = 0; k < 4; k++) { float v = c[k][(size_t)y * s->w + x] * 255 + 0.5f; s->px[(size_t)y * s->stride + x * 4 + k] = (uint8_t)(v > 255 ? 255 : v); }
	for (int k = 0; k < 4; k++) free(c[k]);
}
void RShadowFromAlpha(RSurf *out, const RSurf *src, double sigma, RColor tint)
{
	int w = src->w, h = src->h; float *a = malloc((size_t)w * h * sizeof(float));
	for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) a[(size_t)y * w + x] = src->px[(size_t)y * src->stride + x * 4 + 3] * (1.0f / 255);
	GaussianFloat(a, w, h, sigma);
	for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
		float k = a[(size_t)y * w + x] * tint.a; uint8_t *p = out->px + (size_t)y * out->stride + x * 4;
		p[0] = (uint8_t)(tint.b * k * 255 + 0.5f); p[1] = (uint8_t)(tint.g * k * 255 + 0.5f); p[2] = (uint8_t)(tint.r * k * 255 + 0.5f); p[3] = (uint8_t)(k * 255 + 0.5f);
	}
	free(a);
}
