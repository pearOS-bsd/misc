/* Window shadow generator.
 * Model recovered from SkyLight's embedded Metal shader ShadowVerticalBlurRGBA (decompiled/strings, macOS 27.0):
 *   window_alpha W, shadow_alpha S (gaussian of the window shape, shifted down by the vertical offset),
 *   rim_alpha R (small blur of the shape), glow G (inner rim).
 *   rim   = R * rimDensity * (1 - W)                      -> rimColor * rim
 *   shadow.a += S * density * (1 - W) * (1 - rim)          (rim and diffuse shadow do not stack)
 *   inner rim = innerRimColor(white) * G * innerRimDensity * W
 * Structure (nine parts built from a cached blurred prototype) follows CompositorSW::CreateShadowFromMask.
 * The blur kernel itself is our own truncated gaussian; numeric defaults are estimates (see ws_shadow_defaults). */
#include "ws.h"
#include <math.h>
#include <stdlib.h>
#include <string.h>

ws_shadow_params ws_shadow_defaults(int active)
{
	/* stdev/density/offset: measured on macOS windows earlier, not read from SkyLight (AppKit and WindowManager
	 * supply them at run time). Rim values are estimates. */
	ws_shadow_params p;
	/* fitted to captures of real AppKit windows on macOS 27 (gaussian of the shape, shifted down): key window sigma 19, density 0.72, offset 19;
	 * a window that is not key: sigma 19, density 0.41, offset 18. The 1 px inner rim is white at 10 %. */
	if (active) p = (ws_shadow_params){ 19.0f, 0.72f, 19.0f, 0.25f, 1.0f, 0.10f, 1.0f, 0 };
	else        p = (ws_shadow_params){ 19.0f, 0.41f, 18.0f, 0.25f, 1.0f, 0.10f, 1.0f, 0 };
	return p;
}

static float rr_cover(float px, float py, float w, float h, float r)
{
	float cx = px - w * 0.5f, cy = py - h * 0.5f;
	float qx = fabsf(cx) - (w * 0.5f - r), qy = fabsf(cy) - (h * 0.5f - r);
	float ox = qx > 0 ? qx : 0, oy = qy > 0 ? qy : 0;
	float inside = qx > qy ? qx : qy;
	float d = sqrtf(ox * ox + oy * oy) + (inside < 0 ? inside : 0) - r;
	float c = 0.5f - d;
	return c < 0 ? 0 : c > 1 ? 1 : c;
}

static int sigma_to_radius(float sigma) { return (int)(sigma * 2.8f); }

/* separable gaussian, kernel truncated at 2.8 sigma and normalised; zero outside the plane */
static float *blurred(const float *src, int W, int H, float sigma)
{
	float *out = malloc((size_t)W * H * sizeof *out), *tmp = malloc((size_t)W * H * sizeof *tmp);
	if (!out || !tmp) { free(out); free(tmp); return NULL; }
	int rad = sigma_to_radius(sigma);
	if (rad < 1) { memcpy(out, src, (size_t)W * H * sizeof *out); free(tmp); return out; }
	float *k = malloc((size_t)(2 * rad + 1) * sizeof *k), sum = 0;
	if (!k) { free(out); free(tmp); return NULL; }
	for (int i = -rad; i <= rad; i++) { k[i + rad] = expf(-(float)(i * i) / (2 * sigma * sigma)); sum += k[i + rad]; }
	for (int i = 0; i <= 2 * rad; i++) k[i] /= sum;
	for (int y = 0; y < H; y++)
		for (int x = 0; x < W; x++) {
			float s = 0;
			for (int i = -rad; i <= rad; i++) { int xx = x + i; if (xx >= 0 && xx < W) s += src[(size_t)y * W + xx] * k[i + rad]; }
			tmp[(size_t)y * W + x] = s;
		}
	for (int y = 0; y < H; y++)
		for (int x = 0; x < W; x++) {
			float s = 0;
			for (int i = -rad; i <= rad; i++) { int yy = y + i; if (yy >= 0 && yy < H) s += tmp[(size_t)yy * W + x] * k[i + rad]; }
			out[(size_t)y * W + x] = s;
		}
	free(k); free(tmp);
	return out;
}

static int pad_for(const ws_shadow_params *p)
{
	int r = sigma_to_radius(p->stdev), rr = sigma_to_radius(p->rim_radius / 2.8f), ri = sigma_to_radius(p->inner_rim_radius / 2.8f);
	int m = r > rr ? r : rr;
	if (ri > m) m = ri;
	return m + (int)ceilf(fabsf(p->vertical_offset)) + 1;
}

static uint8_t q8(float v) { return (uint8_t)(v <= 0 ? 0 : v >= 1 ? 255 : v * 255.0f + 0.5f); }

/* full computation for one rounded rect */
static ws_surface *direct(int w, int h, int cr, const ws_shadow_params *p, int pad)
{
	int W = w + 2 * pad, H = h + 2 * pad;
	size_t n = (size_t)W * H;
	float *M = calloc(n, sizeof *M), *inv = malloc(n * sizeof *inv);
	if (!M || !inv) { free(M); free(inv); return NULL; }
	for (int y = 0; y < H; y++)
		for (int x = 0; x < W; x++) {
			int in = x >= pad && y >= pad && x < pad + w && y < pad + h;
			float c = in ? rr_cover(x - pad + 0.5f, y - pad + 0.5f, (float)w, (float)h, (float)cr) : 0.0f;
			M[(size_t)y * W + x] = c;
			inv[(size_t)y * W + x] = 1.0f - c;
		}
	float *S = blurred(M, W, H, p->stdev);
	float *R = blurred(M, W, H, p->rim_radius / 2.8f);
	float *G = blurred(inv, W, H, p->inner_rim_radius / 2.8f);
	ws_surface *out = ws_surface_new(W, H);
	if (!S || !R || !G || !out) { free(M); free(inv); free(S); free(R); free(G); ws_surface_free(out); return NULL; }
	int off = (int)lroundf(p->vertical_offset);
	float rc = p->rim_white ? 1.0f : 0.0f;
	for (int y = 0; y < H; y++) {
		uint8_t *row = out->px + (size_t)y * out->stride;
		for (int x = 0; x < W; x++) {
			size_t i = (size_t)y * W + x;
			int sy = y - off;                                  /* shadow shifted down by the offset */
			float s = (sy >= 0 && sy < H) ? S[(size_t)sy * W + x] : 0.0f;
			float win = M[i];
			float comp_w = 1.0f - win;
			float rim = R[i] * p->rim_density * comp_w;
			float a = s * p->density * comp_w * (1.0f - rim);
			float cr_ = rc * rim, cg = rc * rim, cb = rc * rim, ca = rim;      /* outer rim, premultiplied */
			float ir = G[i] * p->inner_rim_density * win;                       /* white inner rim */
			cr_ += ir; cg += ir; cb += ir; ca += ir;
			ca += a;
			row[x * 4 + 0] = q8(cb); row[x * 4 + 1] = q8(cg); row[x * 4 + 2] = q8(cr_); row[x * 4 + 3] = q8(ca);
		}
	}
	free(M); free(inv); free(S); free(R); free(G);
	return out;
}

/* one cached prototype: corners and edge profiles are sliced from it */
static struct { int cr, m; ws_shadow_params p; ws_surface *s; } proto;

static ws_surface *get_proto(int cr, const ws_shadow_params *p, int pad, int m)
{
	if (proto.s && proto.cr == cr && proto.m == m && memcmp(&proto.p, p, sizeof *p) == 0) return proto.s;
	ws_surface_free(proto.s);
	int C = 2 * m + 2;                              /* rect in the prototype is long enough for a true edge */
	proto.s = direct(C - 2 * pad, C - 2 * pad, cr, p, pad);
	proto.cr = cr; proto.m = m; proto.p = *p;
	return proto.s;
}

ws_surface *ws_shadow_make(int w, int h, int cr, const ws_shadow_params *p, int *pad_out)
{
	if (w <= 0 || h <= 0 || !p || p->stdev <= 0) return NULL;
	int pad = pad_for(p), m = 2 * pad + cr + 1;
	int TW = w + 2 * pad, TH = h + 2 * pad;
	ws_surface *out;
	if (TW < 2 * m + 2 || TH < 2 * m + 2) {
		out = direct(w, h, cr, p, pad);           /* small window: no point in slicing */
	} else {
		ws_surface *P = get_proto(cr, p, pad, m);
		if (!P) return NULL;
		out = ws_surface_new(TW, TH);
		if (!out) return NULL;
		int C = P->w;
		for (int y = 0; y < TH; y++) {
			int py = y < m ? y : y >= TH - m ? C - (TH - y) : m;
			for (int x = 0; x < TW; x++) {
				int px = x < m ? x : x >= TW - m ? C - (TW - x) : m;
				memcpy(out->px + (size_t)y * out->stride + (size_t)x * 4, P->px + (size_t)py * P->stride + (size_t)px * 4, 4);
			}
		}
	}
	if (out && pad_out) *pad_out = pad;
	return out;
}
