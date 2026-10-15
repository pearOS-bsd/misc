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

/* one box pass over `count` lines of `len` pixels; src/dst are line-major, `stride` apart per line, `step` bytes between pixels of a line */
static void box_pass(const uint8_t *src, uint8_t *dst, int len, int count, size_t line_stride, size_t step, int r)
{
	for (int l = 0; l < count; l++) {
		const uint8_t *s = src + (size_t)l * line_stride; uint8_t *d = dst + (size_t)l * line_stride;
		int acc[4] = { 0, 0, 0, 0 };
		for (int k = -r; k <= r; k++) { int x = k < 0 ? 0 : k >= len ? len - 1 : k; for (int c = 0; c < 4; c++) acc[c] += s[(size_t)x * step + c]; }
		int div = 2 * r + 1;
		for (int x = 0; x < len; x++) {
			for (int c = 0; c < 4; c++) d[(size_t)x * step + c] = (uint8_t)((acc[c] + div / 2) / div);
			int add = x + r + 1, sub = x - r; add = add >= len ? len - 1 : add; sub = sub < 0 ? 0 : sub;
			for (int c = 0; c < 4; c++) acc[c] += s[(size_t)add * step + c] - s[(size_t)sub * step + c];
		}
	}
}

void ws_blur_region(ws_surface *img, ws_rect r, float sigma)
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
	for (int p = 0; p < 3; p++) {
		int rad = (sz[p] - 1) / 2;
		box_pass(a, b, r.w, r.h, stride, 4, rad);                    /* horizontal */
		box_pass(b, a, r.h, r.w, 4, stride, rad);                    /* vertical: lines are columns */
	}
	for (int y = 0; y < r.h; y++) memcpy(img->px + (size_t)(r.y + y) * img->stride + (size_t)r.x * 4, a + (size_t)y * stride, stride);
	free(a); free(b);
}
