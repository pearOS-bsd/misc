/* Gaussian blur for backdrops: three successive box blurs per axis approximate a gaussian (box widths from the standard "boxes for gauss" construction),
 * on premultiplied BGRA with edge clamping. The sigma <- radius relation used by the window routines is an estimate (see docs/DESIGN.md). */
#include "ws.h"
#include <math.h>
#include <stdlib.h>
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

float ws_blur_sigma(int radius) { return (float)radius * 0.5f; }

void ws_blur_region(ws_surface *img, ws_rect r, ws_rect wr, float sigma)
{
	if (!img || sigma < 0.3f) return;
	if (r.x < 0) { r.w += r.x; r.x = 0; }
	if (r.y < 0) { r.h += r.y; r.y = 0; }
	if (r.x + r.w > img->w) r.w = img->w - r.x;
	if (r.y + r.h > img->h) r.h = img->h - r.y;
	if (r.w <= 0 || r.h <= 0) return;
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

void ws_glass_regions(ws_surface *img, const ws_glass *g, int n, int ox, int oy)
{
	if (!img || !g || n <= 0) return;
	int any = 0, bx0 = 1 << 30, by0 = 1 << 30, bx1 = -(1 << 30), by1 = -(1 << 30);
	for (int i = 0; i < n; i++) if (g[i].mode > 0 && g[i].rect.w > 3 && g[i].rect.h > 3) {
		any = 1; int x0 = ox + g[i].rect.x, y0 = oy + g[i].rect.y;
		if (x0 < bx0) bx0 = x0; if (y0 < by0) by0 = y0; if (x0 + g[i].rect.w > bx1) bx1 = x0 + g[i].rect.w; if (y0 + g[i].rect.h > by1) by1 = y0 + g[i].rect.h;
	}
	if (!any) return;
	float Lbase = getenv("WS_GLASS_L") ? (float)atof(getenv("WS_GLASS_L")) : 18.0f, amp = getenv("WS_GLASS_AMP") ? (float)atof(getenv("WS_GLASS_AMP")) : 26.0f;
	float LM = getenv("WS_MENU_L") ? (float)atof(getenv("WS_MENU_L")) : 7.0f, AM = getenv("WS_MENU_AMP") ? (float)atof(getenv("WS_MENU_AMP")) : 6.0f;
	int M = (int)ceilf(amp) + 6;
	int cx0 = bx0 - M < 0 ? 0 : bx0 - M, cy0 = by0 - M < 0 ? 0 : by0 - M, cx1 = bx1 + M > img->w ? img->w : bx1 + M, cy1 = by1 + M > img->h ? img->h : by1 + M;
	if (cx1 <= cx0 || cy1 <= cy0) return;
	ws_surface *tmp = ws_surface_new(cx1 - cx0, cy1 - cy0); if (!tmp) return;                 /* the backdrop as it is now: the lens samples from it while the result is written to the image */
	for (int y = cy0; y < cy1; y++) memcpy(tmp->px + (size_t)(y - cy0) * tmp->stride, img->px + (size_t)y * img->stride + (size_t)cx0 * 4, (size_t)(cx1 - cx0) * 4);
	ws_surface *bl = NULL, *bl5 = NULL;                                                     /* the menu materials work on a blurred copy of the backdrop: modes 3, 4 (Menu.caar) sigma 30, mode 5 (the context menu as measured on the Mac) sigma 4.5 */
	for (int i = 0; i < n; i++) { if (g[i].mode == 3 || g[i].mode == 4) { if (!bl) bl = ws_surface_new(tmp->w, tmp->h); } else if (g[i].mode == 5 && !bl5) bl5 = ws_surface_new(tmp->w, tmp->h); }
	if (bl) { memcpy(bl->px, tmp->px, (size_t)tmp->stride * tmp->h); ws_blur_region(bl, (ws_rect){ 0, 0, bl->w, bl->h }, (ws_rect){ 0, 0, bl->w, bl->h }, 30.0f); }
	if (bl5) { memcpy(bl5->px, tmp->px, (size_t)tmp->stride * tmp->h); ws_blur_region(bl5, (ws_rect){ 0, 0, bl5->w, bl5->h }, (ws_rect){ 0, 0, bl5->w, bl5->h }, 4.5f); }
	int x0 = bx0 < 0 ? 0 : bx0, y0 = by0 < 0 ? 0 : by0, x1 = bx1 > img->w ? img->w : bx1, y1 = by1 > img->h ? img->h : by1;
	for (int y = y0; y < y1; y++) for (int x = x0; x < x1; x++) {
		float fx = x + 0.5f, fy = y + 0.5f; int mode;
		float sdf = glass_field(g, n, ox, oy, fx, fy, &mode);
		float cover = clampf(0.5f - sdf, 0, 1); if (cover <= 0) continue;
		if (mode == 5 && bl5) {                                                              /* the context menu of the real Mac: out = f(L) + k (c - L) of the blurred backdrop (fitted to 23 measured backdrops, rms 3.8 / 255), f(L) = 0.1213 + 0.4825 (2L - L^2), L = .1886 r + .7455 g + .0659 b, k = 1.091; a 1 px highlight at the edge, strong on horizontal edges */
			int bxp = x - cx0, byp = y - cy0; if (bxp < 0 || byp < 0 || bxp >= bl5->w || byp >= bl5->h) continue;
			float dd = -sdf; if (dd < 0) dd = 0;
			int dm; float gx = glass_field(g, n, ox, oy, fx + 1, fy, &dm) - glass_field(g, n, ox, oy, fx - 1, fy, &dm), gy = glass_field(g, n, ox, oy, fx, fy + 1, &dm) - glass_field(g, n, ox, oy, fx, fy - 1, &dm);
			float gl = sqrtf(gx * gx + gy * gy), ny = gl > 1e-4f ? fabsf(gy / gl) : 1.0f, nxo = gl > 1e-4f ? gx / gl : 0, nyo = gl > 1e-4f ? gy / gl : -1;
			/* the lens of the liquid glass: at the edge the backdrop is taken from beyond it (a band of LM px, up to AM px out), so that a dark window outside dims the top edge of the menu and a light one lights its bottom edge, as in the pixels of the real menu */
			float shift = dd < LM ? AM * sinf(3.14159265f * dd / LM) : 0; float s3[3]; sample_bilinear(bl5, (fx + nxo * shift) - cx0, (fy + nyo * shift) - cy0, s3);
			float c[3] = { s3[2], s3[1], s3[0] }, L = 0.1886f * c[0] + 0.7455f * c[1] + 0.0659f * c[2], f = 0.1213f + 0.4825f * (2 * L - L * L); (void)bxp; (void)byp;
			float rim = dd < 1.0f ? 0.10f + 0.177f * ny : 0.042f * ny * expf(-(dd - 1.5f) / 3.8f);
			uint8_t *dp = img->px + (size_t)y * img->stride + (size_t)x * 4;
			for (int k = 0; k < 3; k++) { float o = f + 1.091f * (c[k] - L); o = clampf(o, 0, 1); o = o * (1 - rim) + rim; dp[2 - k] = (uint8_t)(dp[2 - k] * (1 - cover) + o * 255.0f * cover + 0.5f); }
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
}

void ws_glass_region(ws_surface *img, ws_rect rect, int radius, int mode)
{
	ws_glass g = { rect, radius, mode }; ws_glass_regions(img, &g, 1, 0, 0);
}
