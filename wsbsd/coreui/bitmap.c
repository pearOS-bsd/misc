/* The bitmaps of an asset catalogue: a CSI "MLEC" payload is a list of chunks (bands of rows), each compressed with LZFSE (4) or, in the newer catalogues, with vImage's "Deepmap 2" (11) codec:
 * tiles of an image stored as an LZFSE stream of prediction residuals (per row Paeth / left / up / mean, in a reversible YCC colour space) or of raw pixels or of palette indices (ported from vImage's Deepmap2Decode*). */
#include "car.h"
#include <stdlib.h>
#include <string.h>
#include "lzfse/lzfse.h"
#include <stdio.h>
#define DBG(...) do { if (getenv("CAR_DEBUG")) fprintf(stderr, __VA_ARGS__); } while (0)

static uint32_t le32(const uint8_t *p) { return (uint32_t)p[3] << 24 | p[2] << 16 | p[1] << 8 | p[0]; }
static uint16_t le16(const uint8_t *p) { return (uint16_t)(p[1] << 8 | p[0]); }

static int bpp_of(int fmt) { static const int t[5] = { 0, 1, 2, 3, 4 }; return fmt >= 1 && fmt <= 4 ? t[fmt] : 0; }

/* one tile (w x h pixels of `fmt`, mode 2 = the predictive codec) from `src`; writes w*h*bpp bytes to out (rows of w*bpp) */
static int tile_default(int fmt, int shift, int w, int h, const uint8_t *src, size_t n, uint8_t *out)
{
	int alpha = !(fmt & 1), ycc = fmt != 1 && fmt != 2;
	size_t wh = (size_t)w * h, planes = ycc ? 6 : 2, need = ((size_t)h + (alpha ? wh : 0) + planes * wh + 15) & ~(size_t)15;      /* the stream is padded to 16 bytes */
	uint8_t *buf = malloc(need + 16); if (!buf) return -1;
	size_t got = lzfse_decode_buffer(buf, need + 16, src, n, NULL);
	if (got != need) { DBG("default: lzfse gave %zu want %zu (len %zu)\n", got, need, n); free(buf); return -1; }
	const uint8_t *al = buf, *filt = buf + (alpha ? wh : 0), *hi = filt + h, *lo = hi + (ycc ? 3 : 1) * wh;
	int nch = ycc ? 3 : 1; size_t rowc = (size_t)w * nch;
	int16_t *prev = calloc(rowc + 3, 2), *cur = calloc(rowc + 3, 2), *res = calloc(rowc + 3, 2); if (!prev || !cur || !res) { free(buf); free(prev); free(cur); free(res); return -1; }
	int bpp = bpp_of(fmt);
	for (int y = 0; y < h; y++) {
		for (size_t i = 0; i < rowc; i++) { unsigned u = hi[y * rowc + i] << 8 | lo[y * rowc + i]; int v = (int)(u >> 1); res[i] = (int16_t)((lo[y * rowc + i] & 1) ? -v : v); }
		int f = filt[y];
		if (f == 0) memcpy(cur, res, rowc * 2);
		else if (f == 2) { for (int c = 0; c < nch; c++) cur[c] = res[c]; for (size_t i = nch; i < rowc; i++) cur[i] = (int16_t)(res[i] + cur[i - nch]); }
		else if (f == 3) { for (size_t i = 0; i < rowc; i++) cur[i] = (int16_t)(res[i] + prev[i]); }
		else if (f == 4) { for (int c = 0; c < nch; c++) cur[c] = (int16_t)(res[c] + prev[c]); for (size_t i = nch; i < rowc; i++) { int s = cur[i - nch] + prev[i] + 1; cur[i] = (int16_t)(res[i] + (s / 2)); } }
		else if (f == 1) {
			for (int c = 0; c < nch; c++) cur[c] = (int16_t)(res[c] + prev[c]);
			for (int x = 1; x < w; x++) {                                                                  /* the choice is made on the first channel and applies to all */
				size_t i = (size_t)x * nch; int a = cur[i - nch], b = prev[i], c0 = prev[i - nch];
				int left = abs(b - c0) <= abs(a - c0);
				for (int c = 0; c < nch; c++) cur[i + c] = (int16_t)(res[i + c] + (left ? cur[i - nch + c] : prev[i + c]));
			}
		} else { free(buf); free(prev); free(cur); free(res); return -1; }
		uint8_t *o = out + (size_t)y * w * bpp;
		for (int x = 0; x < w; x++) {
			if (ycc) {
				int y0 = cur[3 * x], u = (int16_t)((unsigned)(uint16_t)cur[3 * x + 1] << shift), v = (int16_t)((unsigned)(uint16_t)cur[3 * x + 2] << shift);
				int a = (y0 - ((v + (v < 0)) >> 1)) & 255, b = (a - ((u + (u < 0)) >> 1)) & 255;
				uint8_t r = (uint8_t)(b + u), g = (uint8_t)(v + a), bl = (uint8_t)b;
				if (fmt == 4) { o[4 * x] = r; o[4 * x + 1] = g; o[4 * x + 2] = bl; o[4 * x + 3] = al[(size_t)y * w + x]; } else { o[3 * x] = r; o[3 * x + 1] = g; o[3 * x + 2] = bl; }
			} else if (fmt == 2) { o[2 * x] = (uint8_t)cur[x]; o[2 * x + 1] = al[(size_t)y * w + x]; } else o[x] = (uint8_t)cur[x];
		}
		int16_t *t = prev; prev = cur; cur = t;
	}
	(void)al; free(buf); free(prev); free(cur); free(res); return 0;
}

static int tile_palette(const uint32_t *pal, int count, int type, int w, int h, const uint8_t *src, size_t n, uint8_t *out)
{
	size_t wh = (size_t)w * h, need = type == 3 ? 2 * wh : count > 256 ? 2 * wh : wh; if (need < 4096) return -1;
	uint8_t *buf = malloc(need + 16); if (!buf) return -1;
	size_t got = lzfse_decode_buffer(buf, need, src, n, NULL); if (got != need) { free(buf); return -1; }
	for (size_t i = 0; i < wh; i++) {
		uint32_t px;
		if (type == 3) { unsigned ix = buf[wh + i]; px = (pal[ix < (unsigned)count ? ix : 0] & 0xffffff) | (uint32_t)buf[i] << 24; }
		else { unsigned ix = count > 256 ? (unsigned)(buf[2 * i] | buf[2 * i + 1] << 8) : buf[i]; if (ix >= (unsigned)count) { free(buf); return -1; } px = pal[ix]; }
		out[4 * i] = (uint8_t)px; out[4 * i + 1] = (uint8_t)(px >> 8); out[4 * i + 2] = (uint8_t)(px >> 16); out[4 * i + 3] = (uint8_t)(px >> 24);
	}
	free(buf); return 0;
}

static int tile_lossless(int fmt, int w, int h, const uint8_t *src, size_t n, uint8_t *out)
{
	size_t need = (size_t)w * h * bpp_of(fmt); if (need < 4096) return -1;                                  /* small tiles use Apple's LZBITMAP, not implemented */
	size_t got = lzfse_decode_buffer(out, need, src, n, NULL); return got == need ? 0 : -1;
}

/* a "dmp2" image of `bw` x `bh` pixels into `dst` (stride bytes per row) */
static int dmp2_decode(const uint8_t *p, size_t n, int bw, int bh, uint8_t *dst, size_t stride, int want_fmt)
{
	if (n < 12 || memcmp(p, "dmp2", 4)) return -1;
	int mode = p[4], shift = p[5] ? 1 : 0, fmt = p[7], tw = le16(p + 8), th = le16(p + 10); size_t pos = 12; (void)want_fmt;
	int bpp = bpp_of(fmt); if (!bpp || !tw || !th) return -1;
	if (mode == 1) { for (int y = 0; y < bh; y++) { if (pos + (size_t)bw * bpp > n) return -1; memcpy(dst + y * stride, p + pos, (size_t)bw * bpp); pos += (size_t)bw * bpp; } return 0; }
	uint32_t pal[256]; int pcount = 0, ptype = 0;
	if (mode == 4) {                                                                                           /* 16 byte header: entry count, kind (3: separate alpha plane, 4: indices only), then the entries */
		if (n < 16 || fmt != 4) return -1; pcount = le16(p + 12); ptype = le16(p + 14); if (pcount > 256 || (ptype != 3 && ptype != 4) || pcount * 4 + 16 > (int)n) return -1;
		for (int i = 0; i < pcount; i++) pal[i] = le32(p + 16 + 4 * i);
		pos = 16 + (size_t)pcount * 4;
	}
	for (int ty = 0; ty < bh; ty += th) for (int tx = 0; tx < bw; tx += tw) {
		int w = bw - tx < tw ? bw - tx : tw, h = bh - ty < th ? bh - ty : th;
		if (pos + 4 > n) return -1; uint32_t len = le32(p + pos); pos += 4; if (pos + len > n) return -1;
		uint8_t *t = malloc((size_t)w * h * bpp + 16); if (!t) return -1;
		DBG("tile mode %d fmt %d at %d,%d %dx%d len %u\n", mode, fmt, tx, ty, w, h, len);
		int r = mode == 2 ? tile_default(fmt, shift, w, h, p + pos, len, t) : mode == 3 ? tile_lossless(fmt, w, h, p + pos, len, t) : mode == 4 ? tile_palette(pal, pcount, ptype, w, h, p + pos, len, t) : -1;
		if (r) { DBG("tile failed\n"); free(t); return -1; }
		for (int y = 0; y < h; y++) memcpy(dst + (size_t)(ty + y) * stride + (size_t)tx * bpp, t + (size_t)y * w * bpp, (size_t)w * bpp);
		free(t); pos += len;
	}
	return 0;
}

uint8_t *car_bitmap(const CarRendition *r, int *w, int *h, int *bpp)
{
	const uint8_t *p = r->payload; size_t n = r->payload_len;
	if (n < 16 || memcmp(p, "MLEC", 4)) return NULL;
	int comp = (int)le32(p + 8); int W = r->width, H = r->height;
	int nb = r->pixel_format == 0x41524742 ? 4 : r->pixel_format == 0x47413820 ? 2 : 0; (void)nb;
	size_t pos = 16; int y0 = 0; int ob = 0; int chunked = le32(p + 4) == 1;                              /* version 1 payloads are lists of KCBC bands, version 0 is one stream for the whole image */
	uint8_t *out = NULL;
	while (chunked ? (pos + 20 <= n && !memcmp(p + pos, "KCBC", 4)) : pos == 16) {
		uint32_t rows = chunked ? le32(p + pos + 12) : (uint32_t)H, len = chunked ? le32(p + pos + 16) : le32(p + 12); const uint8_t *blob = p + pos + (chunked ? 20 : 0); if (pos + (chunked ? 20 : 0) + len > n) break;
		if (comp == 11) {
			if (len < 16 || le32(blob) > 1) break;
			uint64_t clen = (uint64_t)le32(blob + 8) | (uint64_t)le32(blob + 12) << 32; if (clen + 16 > len) break;
			if (!ob) { int fmt = blob[16 + 7]; ob = bpp_of(fmt); if (!ob) break; out = calloc((size_t)W * H, (size_t)ob); if (!out) return NULL; }
			if ((int)rows > H - y0 || dmp2_decode(blob + 16, (size_t)clen, W, (int)rows, out + (size_t)y0 * W * ob, (size_t)W * ob, 0)) { free(out); return NULL; }
		} else if (comp == 4) {
			if (!ob) { ob = r->pixel_format == 0x47413820 ? 2 : r->pixel_format == 0x47413136 ? 4 : 4; out = calloc((size_t)W * H, (size_t)ob); if (!out) return NULL; }
			size_t need = (size_t)rows * W * ob; size_t got = lzfse_decode_buffer(out + (size_t)y0 * W * ob, need, blob, len, NULL);
			if (got != need) { free(out); return NULL; }
			if (got == need && rows > 0) {                                                  /* the rows of some images (the packed atlases) are padded: 218 pixels of 4 bytes in 896 bytes. The decoder stops at the size asked for, so ask for more and look at what came out */
				static const int align[] = { 16, 32, 64, 128 };
				size_t big = (size_t)rows * (W * (size_t)ob + 128); uint8_t *tmp = malloc(big);
				if (tmp) { size_t g2 = lzfse_decode_buffer(tmp, big, blob, len, NULL); size_t row = (size_t)W * ob;
					if (g2 < big && g2 > need && g2 % rows == 0) { size_t st = g2 / rows; int ok = 0; for (unsigned a = 0; a < 4 && !ok; a++) if (st == ((row + align[a] - 1) / align[a]) * align[a]) ok = 1;
						if (ok || st > row) for (uint32_t yy = 0; yy < rows; yy++) memcpy(out + ((size_t)y0 + yy) * row, tmp + yy * st, row); }
					free(tmp); } }
		} else break;
		y0 += (int)rows; pos += (chunked ? 20 : 0) + len; if (!chunked) break;
	}
	if (!out || y0 != H) { free(out); return NULL; }
	*w = W; *h = H; *bpp = ob; return out;
}

uint8_t *car_bitmap_linked(const CarFile *c, const CarRendition *r, int *w, int *h, int *bpp)
{
	if (r->payload_len) return car_bitmap(r, w, h, bpp);
	size_t l = 0; const uint8_t *k = car_tlv(r, 1010, &l);
	if (!k || l < 32 || memcmp(k, "KLNI", 4)) return NULL;
	uint32_t x = k[8] | k[9] << 8 | k[10] << 16 | (uint32_t)k[11] << 24, y = k[12] | k[13] << 8 | k[14] << 16 | (uint32_t)k[15] << 24, rw = k[16] | k[17] << 8 | k[18] << 16 | (uint32_t)k[19] << 24, rh = k[20] | k[21] << 8 | k[22] << 16 | (uint32_t)k[23] << 24;
	int want[32]; for (int i = 1; i < 32; i++) want[i] = 0;                /* the key lists the attributes that are not 0 (a record of 20 bytes after a 6 byte header) */
	for (size_t o = 30; o + 4 <= l; o += 4) { int id = k[o] | k[o + 1] << 8, v = k[o + 2] | k[o + 3] << 8; if (!id && !v) break; if (id > 0 && id < 32) want[id] = v; }
	for (int i = 0; i < car_count(c); i++) {
		CarRendition a; if (car_rendition(c, i, &a) || !a.payload_len || strncmp(a.name, "ZZZZPackedAsset", 15)) continue;
		int ok = 1; for (int id = 1; id < 32 && ok; id++) if ((a.attr[id] < 0 ? 0 : a.attr[id]) != want[id]) ok = 0; if (!ok) continue;
		int aw, ah, ab; uint8_t *px = car_bitmap(&a, &aw, &ah, &ab); if (!px || ab != 4 || x + rw > (uint32_t)aw || y + rh > (uint32_t)ah) { free(px); continue; }
		y = (uint32_t)ah - y - rh;                                                       /* the rectangle's y is counted from the bottom of the atlas */
		uint8_t *out = malloc((size_t)rw * rh * 4); if (!out) { free(px); return NULL; }
		for (uint32_t row = 0; row < rh; row++) memcpy(out + (size_t)row * rw * 4, px + ((size_t)(y + row) * aw + x) * 4, (size_t)rw * 4);
		free(px); *w = (int)rw; *h = (int)rh; *bpp = 4; return out;
	}
	return NULL;
}
