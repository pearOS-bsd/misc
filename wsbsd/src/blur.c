/* Gaussian blur for backdrops: three successive box blurs per axis approximate a gaussian (box widths from the standard "boxes for gauss" construction),
 * on premultiplied BGRA with edge clamping. The sigma <- radius relation used by the window routines is an estimate (see docs/DESIGN.md). */
#include "ws.h"
#include <math.h>
#include <stdlib.h>
#include <stdio.h>
#include <time.h>
#include <string.h>

static void box_sizes(float sigma, int n, int *sz)
{
	float w_ideal = sqrtf(12.0f * sigma * sigma / (float)n + 1.0f);
	int wl = (int)floorf(w_ideal); if (wl % 2 == 0) wl--;
	int wu = wl + 2;
	float m_ideal = (12.0f * sigma * sigma - (float)(n * wl * wl) - 4.0f * (float)n * (float)wl - 3.0f * (float)n) / (-4.0f * (float)wl - 4.0f);
	int m = (int)roundf(m_ideal);
	for (int i = 0; i < n; i++) sz[i] = i < m ? wl : wu;
}

/* One horizontal box pass: `count` rows of `len` BGRA pixels, row stride `stride` bytes; sliding sums, the division as a multiply by a 16.16 reciprocal (exact for 8-bit sums of up to 255 * div). */
static void box_pass_h(const uint8_t *src, uint8_t *dst, int len, int count, size_t stride, int r)
{
	int div = 2 * r + 1; uint32_t inv = (uint32_t)(((uint64_t)1 << 24) / (uint32_t)div) + 1;         /* ~ 2^24 / div */
	for (int l = 0; l < count; l++) {
		const uint8_t *s = src + (size_t)l * stride; uint8_t *d = dst + (size_t)l * stride;
		int a0 = 0, a1 = 0, a2 = 0, a3 = 0;
		for (int k = -r; k <= r; k++) { const uint8_t *p = s + 4 * (size_t)(k < 0 ? 0 : k >= len ? len - 1 : k); a0 += p[0]; a1 += p[1]; a2 += p[2]; a3 += p[3]; }
		for (int x = 0; x < len; x++) {
			uint8_t *o = d + 4 * (size_t)x;
			o[0] = (uint8_t)(((uint64_t)a0 * inv + (1u << 23)) >> 24); o[1] = (uint8_t)(((uint64_t)a1 * inv + (1u << 23)) >> 24);
			o[2] = (uint8_t)(((uint64_t)a2 * inv + (1u << 23)) >> 24); o[3] = (uint8_t)(((uint64_t)a3 * inv + (1u << 23)) >> 24);
			int add = x + r + 1, sub = x - r; add = add >= len ? len - 1 : add; sub = sub < 0 ? 0 : sub;
			const uint8_t *pa = s + 4 * (size_t)add, *ps = s + 4 * (size_t)sub;
			a0 += pa[0] - ps[0]; a1 += pa[1] - ps[1]; a2 += pa[2] - ps[2]; a3 += pa[3] - ps[3];
		}
	}
}

/* One vertical box pass done row by row (every column's running sum advances together, so memory is read sequentially instead of one cache line per pixel). */
static void box_pass_v(const uint8_t *src, uint8_t *dst, int w, int h, size_t stride, int r, int *acc)
{
	int div = 2 * r + 1; uint32_t inv = (uint32_t)(((uint64_t)1 << 24) / (uint32_t)div) + 1;
	int n = w * 4;
	memset(acc, 0, (size_t)n * sizeof *acc);
	for (int k = -r; k <= r; k++) { const uint8_t *row = src + (size_t)(k < 0 ? 0 : k >= h ? h - 1 : k) * stride; for (int i = 0; i < n; i++) acc[i] += row[i]; }
	for (int y = 0; y < h; y++) {
		uint8_t *o = dst + (size_t)y * stride;
		for (int i = 0; i < n; i++) o[i] = (uint8_t)(((uint64_t)acc[i] * inv + (1u << 23)) >> 24);
		int add = y + r + 1, sub = y - r; add = add >= h ? h - 1 : add; sub = sub < 0 ? 0 : sub;
		const uint8_t *pa = src + (size_t)add * stride, *ps = src + (size_t)sub * stride;
		for (int i = 0; i < n; i++) acc[i] += pa[i] - ps[i];
	}
}


/* Effect cache. A glass or blur region is a function of the pixels it covers (the backdrop) and its parameters; the backdrop of the Dock, the menu bar or a panel rarely changes from one frame to the next,
 * while the effect costs far more than reading the pixels once. Each call site (parameters hashed into `key`) keeps its last result; when the backdrop hash is the same the result is copied back. */
#include <stdint.h>
typedef struct { uint64_t key, in_hash; int x0, y0, x1, y1; uint8_t *out; size_t cap; } fxslot;
#define FXSLOTS 24
static fxslot fxs[FXSLOTS]; static int fxnext, fx_off;
static uint64_t fx_mix(uint64_t h, uint64_t v) { h ^= v + 0x9e3779b97f4a7c15ULL + (h << 6) + (h >> 2); return h * 0xff51afd7ed558ccdULL; }
static uint64_t fx_hash_rect(const ws_surface *img, int x0, int y0, int x1, int y1)
{
	uint64_t h = 1469598103934665603ULL; size_t bytes = (size_t)(x1 - x0) * 4;
	for (int y = y0; y < y1; y++) {
		const uint8_t *p = img->px + (size_t)y * img->stride + (size_t)x0 * 4; size_t i = 0;
		for (; i + 8 <= bytes; i += 8) { uint64_t v; memcpy(&v, p + i, 8); h = (h ^ v) * 1099511628211ULL; h ^= h >> 29; }
		for (; i < bytes; i++) h = (h ^ p[i]) * 1099511628211ULL;
	}
	return h;
}
static fxslot *fx_find(uint64_t key) { for (int i = 0; i < FXSLOTS; i++) if (fxs[i].out && fxs[i].key == key) return &fxs[i]; return NULL; }
/* 1 and the rectangle copied into img when the result for this key and backdrop is known */
static int fx_restore(ws_surface *img, uint64_t key, uint64_t in_hash, int x0, int y0, int x1, int y1)
{
	if (fx_off) return 0;
	fxslot *f = fx_find(key); if (!f || f->in_hash != in_hash || f->x0 != x0 || f->y0 != y0 || f->x1 != x1 || f->y1 != y1) return 0;
	size_t rb = (size_t)(x1 - x0) * 4;
	for (int y = y0; y < y1; y++) memcpy(img->px + (size_t)y * img->stride + (size_t)x0 * 4, f->out + (size_t)(y - y0) * rb, rb);
	return 1;
}
static void fx_store(const ws_surface *img, uint64_t key, uint64_t in_hash, int x0, int y0, int x1, int y1)
{
	if (fx_off || x1 <= x0 || y1 <= y0) return;
	fxslot *f = fx_find(key); if (!f) { f = &fxs[fxnext]; fxnext = (fxnext + 1) % FXSLOTS; }
	size_t rb = (size_t)(x1 - x0) * 4, need = rb * (size_t)(y1 - y0);
	if (f->cap < need) { free(f->out); f->out = malloc(need); f->cap = f->out ? need : 0; if (!f->out) return; }
	for (int y = y0; y < y1; y++) memcpy(f->out + (size_t)(y - y0) * rb, img->px + (size_t)y * img->stride + (size_t)x0 * 4, rb);
	f->key = key; f->in_hash = in_hash; f->x0 = x0; f->y0 = y0; f->x1 = x1; f->y1 = y1;
}

float ws_blur_sigma(int radius) { return (float)radius * 0.5f; }

void ws_blur_region(ws_surface *img, ws_rect r, ws_rect wr, float sigma)
{
	if (!img || sigma < 0.3f) return;
	if (r.x < 0) { r.w += r.x; r.x = 0; }
	if (r.y < 0) { r.h += r.y; r.y = 0; }
	if (r.x + r.w > img->w) r.w = img->w - r.x;
	if (r.y + r.h > img->h) r.h = img->h - r.y;
	if (r.w <= 0 || r.h <= 0) return;
	int cx0 = wr.x < r.x ? r.x : wr.x, cy0 = wr.y < r.y ? r.y : wr.y, cx1 = wr.x + wr.w > r.x + r.w ? r.x + r.w : wr.x + wr.w, cy1 = wr.y + wr.h > r.y + r.h ? r.y + r.h : wr.y + wr.h;
	uint64_t ckey = 0, chash = 0; int cache = !fx_off && img->w >= 256 && cx1 > cx0 && cy1 > cy0;       /* (blurs of the glass's own working copies are small and not cached) */
	if (cache) { ckey = fx_mix(fx_mix(fx_mix(fx_mix(fx_mix(1, (uint64_t)r.x), (uint64_t)r.y), (uint64_t)r.w << 20 | (uint64_t)r.h), (uint64_t)(wr.x + 100000) << 32 | (uint32_t)(wr.y + 100000)), (uint64_t)wr.w << 20 ^ (uint64_t)wr.h ^ (uint64_t)(sigma * 100) << 40);
		chash = fx_hash_rect(img, r.x, r.y, r.x + r.w, r.y + r.h); if (fx_restore(img, ckey, chash, cx0, cy0, cx1, cy1)) return; }
	size_t stride = (size_t)r.w * 4;
	uint8_t *a = malloc(stride * (size_t)r.h), *b = malloc(stride * (size_t)r.h);
	if (!a || !b) { free(a); free(b); return; }
	for (int y = 0; y < r.h; y++) memcpy(a + (size_t)y * stride, img->px + (size_t)(r.y + y) * img->stride + (size_t)r.x * 4, stride);
	int sz[3]; box_sizes(sigma, 3, sz);
	int *acc = malloc((size_t)r.w * 4 * sizeof *acc);
	if (!acc) { free(a); free(b); return; }
	for (int p = 0; p < 3; p++) {
		int rad = (sz[p] - 1) / 2;
		box_pass_h(a, b, r.w, r.h, stride, rad);
		box_pass_v(b, a, r.w, r.h, stride, rad, acc);
	}
	free(acc);
	int x0 = wr.x < r.x ? r.x : wr.x, y0 = wr.y < r.y ? r.y : wr.y, x1 = wr.x + wr.w > r.x + r.w ? r.x + r.w : wr.x + wr.w, y1 = wr.y + wr.h > r.y + r.h ? r.y + r.h : wr.y + wr.h;
	for (int y = y0; y < y1; y++) memcpy(img->px + (size_t)y * img->stride + (size_t)x0 * 4, a + (size_t)(y - r.y) * stride + (size_t)(x0 - r.x) * 4, (size_t)(x1 - x0) * 4);
	free(a); free(b);
	if (cache) fx_store(img, ckey, chash, cx0, cy0, cx1, cy1);
}

/* ---- the glass material ("Liquid Glass"), as measured on the real Dock over a high-contrast pattern: there is NO blur inside (lines and stripes stay crisp), the interior is the backdrop darkened to
 * about 0.69 (white -> 176), and the edge band (about 18 px) is a lens that PULLS content in from beyond the edge (a line 18 px outside the bar shows up right at its edge, bent), with a thin specular
 * rim lit from the top left. mode 1: regular, 2: clear (lighter tint, thinner lens) ---- */
#include <math.h>
static float clampf(float v, float lo, float hi) { return v < lo ? lo : v > hi ? hi : v; }
static void sample_bilinear(const ws_surface *s, float x, float y, float out[3])
{
	x = clampf(x - 0.5f, 0, (float)s->w - 1.001f); y = clampf(y - 0.5f, 0, (float)s->h - 1.001f);
	int x0 = (int)x, y0 = (int)y; float fx = x - x0, fy = y - y0;
	const uint8_t *p00 = s->px + (size_t)y0 * s->stride + (size_t)x0 * 4, *p10 = p00 + 4, *p01 = p00 + s->stride, *p11 = p01 + 4;
	for (int c = 0; c < 3; c++) out[c] = ((p00[c] * (1 - fx) + p10[c] * fx) * (1 - fy) + (p01[c] * (1 - fx) + p11[c] * fx) * fy) / 255.0f;      /* BGRA: c = 0 blue */
}

/* the signed distance (< 0 inside) of the rounded rectangle g (screen coordinates) from the point (x, y) */
static float glass_sdf(const ws_glass *g, int ox, int oy, float x, float y)
{
	float hw = g->rect.w / 2.0f, hh = g->rect.h / 2.0f, r = (float)(g->radius > 0 ? g->radius : 0); if (r > hh) r = hh; if (r > hw) r = hw;
	float px = x - (ox + g->rect.x + hw), py = y - (oy + g->rect.y + hh), qx = fabsf(px) - (hw - r), qy = fabsf(py) - (hh - r);
	float mx = qx > 0 ? qx : 0, my = qy > 0 ? qy : 0;
	return sqrtf(mx * mx + my * my) + fminf(fmaxf(qx, qy), 0) - r;
}
/* all the glass shapes of a window as one: the polynomial smooth minimum makes shapes that come close (the buttons of a toolbar, the groups of a container) melt into each other */
static float glass_field(const ws_glass *g, int n, int ox, int oy, float x, float y, int *mode)
{
	float f = 1e9f; *mode = 1; const float k = 14.0f;
	for (int i = 0; i < n; i++) {
		if (g[i].mode <= 0) continue;
		float s = glass_sdf(&g[i], ox, oy, x, y);
		if (f > 1e8f) { f = s; *mode = g[i].mode; continue; }
		float h = fmaxf(k - fabsf(f - s), 0) / k; float m = fminf(f, s) - h * h * k * 0.25f;
		if (s < f) *mode = g[i].mode;
		f = m;
	}
	return f;
}

/* the strength of the glass lens (the displacement of the backdrop at the edges), 1 = as measured / fitted; the user's setting is a number in /var/tmp/wsd-glass-intensity (UITest's slider writes it), WS_GLASS_INTENSITY overrides; read once a second */
static float glass_intensity(void)
{
	static float v = 1.0f; static time_t at;
	time_t now = time(NULL); if (now == at) return v; at = now;
	const char *e = getenv("WS_GLASS_INTENSITY"); if (e) { v = (float)atof(e); }
	else { FILE *f = fopen("/var/tmp/wsd-glass-intensity", "r"); if (f) { float x; if (fscanf(f, "%f", &x) == 1) v = x; fclose(f); } else v = 1.0f; }
	if (v < 0) v = 0; if (v > 3) v = 3; return v;
}
void ws_glass_regions(ws_surface *img, const ws_glass *g, int n, int ox, int oy)
{
	if (!img || !g || n <= 0) return;
	int any = 0, bx0 = 1 << 30, by0 = 1 << 30, bx1 = -(1 << 30), by1 = -(1 << 30);
	for (int i = 0; i < n; i++) if (g[i].mode > 0 && g[i].rect.w > 3 && g[i].rect.h > 3) {
		any = 1; int x0 = ox + g[i].rect.x, y0 = oy + g[i].rect.y;
		if (x0 < bx0) bx0 = x0; if (y0 < by0) by0 = y0; if (x0 + g[i].rect.w > bx1) bx1 = x0 + g[i].rect.w; if (y0 + g[i].rect.h > by1) by1 = y0 + g[i].rect.h;
	}
	if (!any) return;
	float Lbase = getenv("WS_GLASS_L") ? (float)atof(getenv("WS_GLASS_L")) : 18.0f, amp = getenv("WS_GLASS_AMP") ? (float)atof(getenv("WS_GLASS_AMP")) : 15.0f;
	float LM = getenv("WS_MENU_L") ? (float)atof(getenv("WS_MENU_L")) : 11.0f, AX = getenv("WS_MENU_AX") ? (float)atof(getenv("WS_MENU_AX")) : 12.0f, AY = getenv("WS_MENU_AY") ? (float)atof(getenv("WS_MENU_AY")) : 18.0f;       /* the lens of the menu glass: the backdrop is taken from a point displaced by (AX, AY) sin(pi d / LM): fitted on the Mac with striped backdrops (+x 12 over 8 px on the vertical stripes, +y 16-20 over 14 px on the horizontal ones) */
	float gi = glass_intensity(); amp *= gi; AX *= gi; AY *= gi;       /* the lens strength setting */
	int M = (int)ceilf(amp) + 6;
	int cx0 = bx0 - M < 0 ? 0 : bx0 - M, cy0 = by0 - M < 0 ? 0 : by0 - M, cx1 = bx1 + M > img->w ? img->w : bx1 + M, cy1 = by1 + M > img->h ? img->h : by1 + M;
	if (cx1 <= cx0 || cy1 <= cy0) return;
	int ox0 = bx0 < 0 ? 0 : bx0, oy0 = by0 < 0 ? 0 : by0, ox1 = bx1 > img->w ? img->w : bx1, oy1 = by1 > img->h ? img->h : by1;
	uint64_t gkey = fx_mix(fx_mix(fx_mix(2 + (uint64_t)(gi * 1000) * 7, (uint64_t)n), (uint64_t)(ox + 100000) << 32 | (uint32_t)(oy + 100000)), (uint64_t)img->w << 20 | (uint64_t)img->h);
	for (int i = 0; i < n; i++) { gkey = fx_mix(gkey, (uint64_t)(g[i].rect.x + 100000) << 32 | (uint32_t)(g[i].rect.y + 100000)); gkey = fx_mix(gkey, (uint64_t)g[i].rect.w << 40 ^ (uint64_t)g[i].rect.h << 20 ^ (uint64_t)g[i].radius << 8 ^ (uint64_t)g[i].mode); }
	uint64_t ghash = fx_hash_rect(img, cx0, cy0, cx1, cy1);
	if (ox1 > ox0 && oy1 > oy0 && fx_restore(img, gkey, ghash, ox0, oy0, ox1, oy1)) return;
	ws_surface *tmp = ws_surface_new(cx1 - cx0, cy1 - cy0); if (!tmp) return;                 /* the backdrop as it is now: the lens samples from it while the result is written to the image */
	for (int y = cy0; y < cy1; y++) memcpy(tmp->px + (size_t)(y - cy0) * tmp->stride, img->px + (size_t)y * img->stride + (size_t)cx0 * 4, (size_t)(cx1 - cx0) * 4);
	ws_surface *bl = NULL, *bl5 = NULL;                                                     /* the menu materials work on a blurred copy of the backdrop: modes 3, 4 (Menu.caar) sigma 30, mode 5 (the context menu as measured on the Mac) sigma 4.5 */
	for (int i = 0; i < n; i++) { if (g[i].mode == 3 || g[i].mode == 4) { if (!bl) bl = ws_surface_new(tmp->w, tmp->h); } else if ((g[i].mode == 5 || g[i].mode == 6 || g[i].mode == 7 || g[i].mode == 8) && !bl5) bl5 = ws_surface_new(tmp->w, tmp->h); }
	fx_off++;
	if (bl) { memcpy(bl->px, tmp->px, (size_t)tmp->stride * tmp->h); ws_blur_region(bl, (ws_rect){ 0, 0, bl->w, bl->h }, (ws_rect){ 0, 0, bl->w, bl->h }, 30.0f); }
	if (bl5) { memcpy(bl5->px, tmp->px, (size_t)tmp->stride * tmp->h); ws_blur_region(bl5, (ws_rect){ 0, 0, bl5->w, bl5->h }, (ws_rect){ 0, 0, bl5->w, bl5->h }, 7.0f); }
	fx_off--;
	int x0 = bx0 < 0 ? 0 : bx0, y0 = by0 < 0 ? 0 : by0, x1 = bx1 > img->w ? img->w : bx1, y1 = by1 > img->h ? img->h : by1;
	for (int y = y0; y < y1; y++) for (int x = x0; x < x1; x++) {
		float fx = x + 0.5f, fy = y + 0.5f; int mode;
		float sdf = glass_field(g, n, ox, oy, fx, fy, &mode);
		float cover = clampf(0.5f - sdf, 0, 1); if (cover <= 0) continue;
		if ((mode == 5 || mode == 6 || mode == 7 || mode == 8) && bl5) {                                                              /* the context menu of the real Mac: out = f(L) + k (c - L) of the blurred backdrop (fitted to 23 measured backdrops, rms 3.8 / 255), f(L) = 0.1213 + 0.4825 (2L - L^2), L = .1886 r + .7455 g + .0659 b, k = 1.091; a 1 px highlight at the edge, strong on horizontal edges */
			int bxp = x - cx0, byp = y - cy0; if (bxp < 0 || byp < 0 || bxp >= bl5->w || byp >= bl5->h) continue;
			float dd = -sdf; if (dd < 0) dd = 0;
			int dm; float gx = glass_field(g, n, ox, oy, fx + 1, fy, &dm) - glass_field(g, n, ox, oy, fx - 1, fy, &dm), gy = glass_field(g, n, ox, oy, fx, fy + 1, &dm) - glass_field(g, n, ox, oy, fx, fy - 1, &dm);
			float gl = sqrtf(gx * gx + gy * gy), ny = gl > 1e-4f ? fabsf(gy / gl) : 1.0f, nxo = gl > 1e-4f ? gx / gl : 0, nyo = gl > 1e-4f ? gy / gl : -1;
			/* the lens of the liquid glass: at the edge the backdrop is taken from beyond it (a band of LM px, up to AM px out), so that a dark window outside dims the top edge of the menu and a light one lights its bottom edge, as in the pixels of the real menu */
			/* the displacement per edge (fitted on the Mac): left, right and bottom 12 px over 8 px, the top 18 px over 14 px; x to the right, y down: inward at the top and left, outward at the bottom and right */
			float sx = 0, sy = 0; for (int q = 0; q < n && (mode == 5 || mode == 8); q++) if (g[q].mode == 5 || g[q].mode == 8) { float rx = ox + g[q].rect.x, ry = oy + g[q].rect.y; if (fx >= rx && fx < rx + g[q].rect.w && fy >= ry && fy < ry + g[q].rect.h) {
				float dl = fx - rx, dr = rx + g[q].rect.w - fx, dt = fy - ry, db = ry + g[q].rect.h - fy, dx = dl < dr ? dl : dr;
				if (dx < 8.0f) sx = AX * sinf(3.14159265f * dx / 8.0f); if (dt < 14.0f && dt <= db) sy = AY * sinf(3.14159265f * dt / 14.0f); else if (db < 8.0f) sy = 12.0f * gi * sinf(3.14159265f * db / 8.0f); break; } }
			float s3[3]; sample_bilinear(bl5, (fx + sx) - cx0, (fy + sy) - cy0, s3);
			if (mode == 6 || mode == 7) {                                                       /* the Dock's bar: the backdrop is hardly blurred (a stripe edge goes 176, 146, 66, 14 over 3 px on the Mac: sigma 1.1), 3 x 3 taps */
				float acc[3] = { 0, 0, 0 }, wt = 0; for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) { float w = (dx && dy) ? 0.44f : (dx || dy) ? 0.66f : 1.0f, t3[3]; sample_bilinear(tmp, fx + dx - cx0, fy + dy - cy0, t3); for (int k = 0; k < 3; k++) acc[k] += w * t3[k]; wt += w; }
				for (int k = 0; k < 3; k++) s3[k] = acc[k] / wt; } (void)nxo; (void)nyo; (void)LM;
			float c[3] = { s3[2], s3[1], s3[0] }, L = 0.1886f * c[0] + 0.7455f * c[1] + 0.0659f * c[2], f = mode == 8 ? 0.4041f + L * (0.6443f + L * (0.1437f - 0.1998f * L)) : mode == 7 ? 0.1216f + L * (0.987f - 0.395f * L) : mode == 6 ? 0.047f + L * (0.856f - 0.213f * L) : 0.12494f + L * (0.86553f - L * (0.24983f + 0.16865f * L));       /* mode 8, the context menu in the Light appearance: uniform greys 0, 64, 128, 192, 255 behind a Dock menu gave 103, 146, 188, 226, 253 of 255 (a cubic through them; the text is black at 85 %); mode 6, the Dock's bar: uniform greys 0, 64, 128, 192, 255 behind it gave 12, 64, 108, 145, 176 on the Mac (a quadratic through them, no lens: the edges are sharp); the rim: the edge row lifts the tone by 29 % of the way to white over black, 17 % over white, then 6.6 % and falling by e^-0.55 per row, top and bottom only (profiles 83/28/21/18 over black, 145/116/113/111 over 128, 189/179/178/177 over 255) */       /* the tone of the glass over uniform greys 0, 64, 128, 192, 255 measured on the Mac (Dock context menu: 32, 82, 122, 143, 146 of 255): a cubic through them (the earlier fit on natural backdrops gave 31, 85, 123, 146, 154) */ (void)bxp; (void)byp;
			float rim = mode == 7 ? 0.0f : mode == 6 ? ny * (floorf(dd) < 1.0f ? 0.292f : floorf(dd) < 9.0f ? 0.066f * expf(-0.55f * (floorf(dd) - 1.0f)) : 0.0f) * (1.0f - 0.26f * L - 0.17f * L * L) : dd < 1.0f ? 0.10f + 0.177f * ny : 0.042f * ny * expf(-(dd - 1.5f) / 3.8f);
			uint8_t *dp = img->px + (size_t)y * img->stride + (size_t)x * 4;
			for (int k = 0; k < 3; k++) { float o = f + 1.091f * (c[k] - L); o = clampf(o, 0, 1); o = o * (1 - rim) + rim; if (mode == 7 && dd < 1.0f) o *= 0.53f; dp[2 - k] = (uint8_t)(dp[2 - k] * (1 - cover) + o * 255.0f * cover + 0.5f); }
			continue;
		}
		if (mode >= 3 && mode < 5 && bl) {                                                               /* Mica: Menu.caar of Aqua.car / DarkAqua.car: a backdrop (gaussian blur 30, saturate), the fill colour over it, the tone layer in darken (light) or lighten (dark) blend */
			int bxp = x - cx0, byp = y - cy0; if (bxp < 0 || byp < 0 || bxp >= bl->w || byp >= bl->h) continue;
			const uint8_t *bp = bl->px + (size_t)byp * bl->stride + (size_t)bxp * 4; int dark = mode == 4;
			float sat = dark ? 2.2f : 2.1f, fill = dark ? 0.157f : 0.965f, fa = dark ? 0.70f : 0.72f, tone = dark ? 0.125f : 0.93f;
			float b = bp[0] / 255.0f, gg = bp[1] / 255.0f, r = bp[2] / 255.0f, lum = 0.2126f * r + 0.7152f * gg + 0.0722f * b;
			float col[3] = { r, gg, b }; for (int c = 0; c < 3; c++) { col[c] = lum + (col[c] - lum) * sat; col[c] = clampf(col[c], 0, 1); col[c] = fill * fa + col[c] * (1 - fa); col[c] = dark ? (col[c] > tone ? col[c] : tone) : (col[c] < tone ? col[c] : tone); }
			uint8_t *dp = img->px + (size_t)y * img->stride + (size_t)x * 4;
			dp[0] = (uint8_t)(dp[0] * (1 - cover) + col[2] * 255.0f * cover + 0.5f); dp[1] = (uint8_t)(dp[1] * (1 - cover) + col[1] * 255.0f * cover + 0.5f); dp[2] = (uint8_t)(dp[2] * (1 - cover) + col[0] * 255.0f * cover + 0.5f);
			continue;
		}
		float d = -sdf; if (d < 0) d = 0;
		int dm; float gx = glass_field(g, n, ox, oy, fx + 1, fy, &dm) - glass_field(g, n, ox, oy, fx - 1, fy, &dm), gy = glass_field(g, n, ox, oy, fx, fy + 1, &dm) - glass_field(g, n, ox, oy, fx, fy - 1, &dm);
		float gl = sqrtf(gx * gx + gy * gy); float nx = gl > 1e-4f ? gx / gl : 0, ny = gl > 1e-4f ? gy / gl : -1;      /* outward normal */
		float L = mode == 2 ? 10.0f : Lbase, A = mode == 2 ? amp * 0.5f : amp;
		float tint = mode == 2 ? 0.90f : 0.69f, lift = mode == 2 ? 0.0f : 0.012f;
		float shift = 0; if (d < L) shift = A * sinf(3.14159265f * d / L);          /* the bevel folds the image: content from up to A pixels beyond the edge, mirrored where the slope reverses (that is where lines look thick) */
		float col[3]; sample_bilinear(tmp, (fx + nx * shift) - cx0, (fy + ny * shift) - cy0, col);
		float light = nx * -0.55f + ny * -0.83f; if (light < 0) light = 0;
		float rim = expf(-d / 1.1f) * (0.10f + 0.50f * light), glow = expf(-d / 5.0f) * 0.05f * light, white = rim + glow;
		for (int c = 0; c < 3; c++) { col[c] = col[c] * tint + lift; col[c] = col[c] * (1 - white) + white; if (col[c] > 1) col[c] = 1; }
		uint8_t *dp = img->px + (size_t)y * img->stride + (size_t)x * 4;
		for (int c = 0; c < 3; c++) dp[c] = (uint8_t)(dp[c] * (1 - cover) + col[c] * 255.0f * cover + 0.5f);
	}
	ws_surface_free(tmp); if (bl) ws_surface_free(bl); if (bl5) ws_surface_free(bl5);
	if (ox1 > ox0 && oy1 > oy0) fx_store(img, gkey, ghash, ox0, oy0, ox1, oy1);
}

void ws_glass_region(ws_surface *img, ws_rect rect, int radius, int mode)
{
	ws_glass g = { rect, radius, mode }; ws_glass_regions(img, &g, 1, 0, 0);
}
