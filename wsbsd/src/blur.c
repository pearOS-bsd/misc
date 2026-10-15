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
