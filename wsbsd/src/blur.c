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

/* ---- the glass material ("Liquid Glass"): what lies behind a rounded rectangle is blurred, its saturation is raised, the edge band acts as a lens (the backdrop is sampled from further inside, so the edge looks
 * thick and bent), a specular rim from a light at the top left and a soft inner shadow at the bottom edge. mode 1: regular, 2: clear (less blur, no tint) ---- */
#include <math.h>
static float clampf(float v, float lo, float hi) { return v < lo ? lo : v > hi ? hi : v; }
static void sample_bilinear(const ws_surface *s, float x, float y, float out[3])
{
	x = clampf(x - 0.5f, 0, (float)s->w - 1.001f); y = clampf(y - 0.5f, 0, (float)s->h - 1.001f);
	int x0 = (int)x, y0 = (int)y; float fx = x - x0, fy = y - y0;
	const uint8_t *p00 = s->px + (size_t)y0 * s->stride + (size_t)x0 * 4, *p10 = p00 + 4, *p01 = p00 + s->stride, *p11 = p01 + 4;
	for (int c = 0; c < 3; c++) out[c] = ((p00[c] * (1 - fx) + p10[c] * fx) * (1 - fy) + (p01[c] * (1 - fx) + p11[c] * fx) * fy) / 255.0f;      /* BGRA: c = 0 blue */
}

void ws_glass_region(ws_surface *img, ws_rect gr, int rad, int mode)
{
	if (!img || gr.w < 4 || gr.h < 4 || mode <= 0) return;
	float sigma = mode == 2 ? 3.0f : 9.0f; int M = (int)ceilf(3.0f * sigma) + 16;
	ws_rect cr = { gr.x - M, gr.y - M, gr.w + 2 * M, gr.h + 2 * M };
	int cx0 = cr.x < 0 ? 0 : cr.x, cy0 = cr.y < 0 ? 0 : cr.y, cx1 = cr.x + cr.w > img->w ? img->w : cr.x + cr.w, cy1 = cr.y + cr.h > img->h ? img->h : cr.y + cr.h;
	if (cx1 <= cx0 || cy1 <= cy0) return;
	ws_surface *tmp = ws_surface_new(cx1 - cx0, cy1 - cy0); if (!tmp) return;
	for (int y = cy0; y < cy1; y++) memcpy(tmp->px + (size_t)(y - cy0) * tmp->stride, img->px + (size_t)y * img->stride + (size_t)cx0 * 4, (size_t)(cx1 - cx0) * 4);
	ws_blur_region(tmp, (ws_rect){ 0, 0, tmp->w, tmp->h }, (ws_rect){ 0, 0, tmp->w, tmp->h }, sigma);
	float hw = gr.w / 2.0f, hh = gr.h / 2.0f, r = (float)(rad > 0 ? rad : 0); if (r > hh) r = hh; if (r > hw) r = hw;
	float L = fminf(16.0f, fminf(gr.w, gr.h) / 3.0f);                                 /* width of the lens band */
	int x0 = gr.x < 0 ? 0 : gr.x, y0 = gr.y < 0 ? 0 : gr.y, x1 = gr.x + gr.w > img->w ? img->w : gr.x + gr.w, y1 = gr.y + gr.h > img->h ? img->h : gr.y + gr.h;
	for (int y = y0; y < y1; y++) for (int x = x0; x < x1; x++) {
		float px = x + 0.5f - gr.x - hw, py = y + 0.5f - gr.y - hh;                  /* relative to the centre */
		float qx = fabsf(px) - (hw - r), qy = fabsf(py) - (hh - r);
		float mx = qx > 0 ? qx : 0, my = qy > 0 ? qy : 0, sdf = sqrtf(mx * mx + my * my) + fminf(fmaxf(qx, qy), 0) - r;      /* < 0 inside */
		float cover = clampf(0.5f - sdf, 0, 1); if (cover <= 0) continue;
		float d = -sdf; if (d < 0) d = 0;
		float nx, ny;                                                               /* outward normal */
		if (qx > 0 && qy > 0) { float l = sqrtf(qx * qx + qy * qy); nx = (px < 0 ? -1 : 1) * qx / l; ny = (py < 0 ? -1 : 1) * qy / l; }
		else if (qx > qy) { nx = px < 0 ? -1.0f : 1.0f; ny = 0; } else { nx = 0; ny = py < 0 ? -1.0f : 1.0f; }
		float shift = 0; if (d < L) { float t = 1 - d / L; shift = t * t * L * 0.85f; }
		float col[3]; sample_bilinear(tmp, (x + 0.5f - nx * shift) - cx0, (y + 0.5f - ny * shift) - cy0, col);
		float gray = 0.114f * col[0] + 0.587f * col[1] + 0.299f * col[2];
		float sat = mode == 2 ? 1.25f : 1.6f;
		for (int c = 0; c < 3; c++) col[c] = clampf(gray + (col[c] - gray) * sat + (mode == 2 ? 0.0f : 0.035f), 0, 1);
		float light = nx * -0.55f + ny * -0.83f; if (light < 0) light = 0;
		float rim = expf(-d / 1.3f), glow = expf(-d / 7.0f);
		float white = (mode == 2 ? 0.0f : 0.05f) + rim * (0.12f + 0.55f * light) + glow * 0.10f * light;
		float shade = expf(-d / 6.0f) * 0.12f * fmaxf(0.0f, nx * 0.25f + ny * 0.95f);
		for (int c = 0; c < 3; c++) { col[c] = col[c] * (1 - shade) * (1 - white) + white; if (col[c] > 1) col[c] = 1; }
		uint8_t *dp = img->px + (size_t)y * img->stride + (size_t)x * 4;
		for (int c = 0; c < 3; c++) dp[c] = (uint8_t)(dp[c] * (1 - cover) + col[c] * 255.0f * cover + 0.5f);
	}
	ws_surface_free(tmp);
}
