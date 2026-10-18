#include <stdlib.h>
#include <string.h>
#include "icns.h"

static uint32_t be32(const uint8_t *p) { return (uint32_t)p[0] << 24 | p[1] << 16 | p[2] << 8 | p[3]; }

/* a 'it32' like channel: runs of literal bytes (0..127: count+1 literals) and repeated bytes (128..255: count-125 copies of the next byte) */
int icns_unpack(const uint8_t *s, size_t sl, uint8_t *d, size_t n)
{
	size_t i = 0, o = 0;
	while (o < n && i < sl) {
		uint8_t c = s[i++];
		if (c < 128) { size_t k = c + 1u; if (i + k > sl || o + k > n) return 0; memcpy(d + o, s + i, k); i += k; o += k; }
		else { size_t k = c - 125u; if (i >= sl || o + k > n) return 0; memset(d + o, s[i++], k); o += k; }
	}
	return o == n;
}

static const struct { const char *type; int px; int png; } PNGTYPES[] = {
	{ "icp4", 16, 1 }, { "icp5", 32, 1 }, { "icp6", 64, 1 }, { "ic07", 128, 1 }, { "ic08", 256, 1 }, { "ic09", 512, 1 }, { "ic10", 1024, 1 },
	{ "ic11", 32, 1 }, { "ic12", 64, 1 }, { "ic13", 256, 1 }, { "ic14", 512, 1 }, { "ic04", 16, 0 }, { "ic05", 32, 0 } };
static const struct { const char *rgb, *mask; int px; } LEGACY[] = { { "is32", "s8mk", 16 }, { "il32", "l8mk", 32 }, { "ih32", "h8mk", 48 }, { "it32", "t8mk", 128 } };

int icns_pick(const uint8_t *f, size_t len, int want, IcnsPick *out)
{
	if (len < 8 || memcmp(f, "icns", 4)) return 0;
	size_t total = be32(f + 4); if (total > len) total = len;
	int bestpx = 0; const uint8_t *bp = NULL; size_t bl = 0; int bjp2 = 0; int legacy = -1;
	int rank_best = 0;                                      /* smallest px >= want, else the largest px */
	for (size_t o = 8; o + 8 <= total; ) {
		const uint8_t *e = f + o; size_t el = be32(e + 4); if (el < 8 || o + el > total) break;
		const uint8_t *d = e + 8; size_t dl = el - 8; int px = 0, kind = -1, jp2 = 0, li = -1;
		for (size_t k = 0; k < sizeof PNGTYPES / sizeof PNGTYPES[0]; k++) if (!memcmp(e, PNGTYPES[k].type, 4) && PNGTYPES[k].png) {
			px = PNGTYPES[k].px; kind = 0;
			if (dl >= 8 && !memcmp(d, "\x89PNG", 4)) jp2 = 0; else if (dl >= 12 && !memcmp(d + 4, "jP  ", 4)) jp2 = 1; else if (dl >= 4 && d[0] == 0xFF && d[1] == 0x4F) jp2 = 1; else kind = -1;
		}
		for (size_t k = 0; kind < 0 && k < 4; k++) if (!memcmp(e, LEGACY[k].rgb, 4)) { px = LEGACY[k].px; kind = 1; li = (int)k; }
		if (kind >= 0 && !(kind == 0 && jp2)) {             /* JPEG 2000 entries are not decoded here */
			int better;
			if (!bp && legacy < 0) better = 1;
			else if (bestpx >= want) better = px >= want && px < bestpx; else better = px > bestpx;
			if (better) { bestpx = px; if (kind == 0) { bp = d; bl = dl; legacy = -1; bjp2 = jp2; } else { bp = d; bl = dl; legacy = li; } rank_best = 1; }
		}
		o += el;
	}
	(void)rank_best; (void)bjp2;
	if (!bp) return 0;
	memset(out, 0, sizeof *out); out->px = bestpx;
	if (legacy < 0) { out->png = bp; out->png_len = bl; return 1; }
	/* legacy: the colour planes of this entry and its mask entry */
	int px = LEGACY[legacy].px; size_t n = (size_t)px * px; uint8_t *planes = malloc(n * 3), *mask = calloc(1, n), *rgba = malloc(n * 4);
	const uint8_t *src = bp; size_t sl = bl;
	if (legacy == 3 && sl >= 4) { src += 4; sl -= 4; }
	if (!planes || !mask || !rgba) { free(planes); free(mask); free(rgba); return 0; }
	int ok = 1;
	if (legacy == 0 && sl == n * 3) memcpy(planes, src, n * 3);                  /* 16 x 16 is32 may be stored uncompressed */
	else {
		/* three runs, one per channel, each decoding to n bytes: decode them in sequence from the same stream */
		size_t i = 0;
		for (int ch = 0; ch < 3 && ok; ch++) {
			size_t o2 = 0; uint8_t *dst = planes + (size_t)ch * n;
			while (o2 < n && i < sl) {
				uint8_t c = src[i++];
				if (c < 128) { size_t k = c + 1u; if (i + k > sl || o2 + k > n) { ok = 0; break; } memcpy(dst + o2, src + i, k); i += k; o2 += k; }
				else { size_t k = c - 125u; if (i >= sl || o2 + k > n) { ok = 0; break; } memset(dst + o2, src[i++], k); o2 += k; }
			}
			if (o2 != n) ok = 0;
		}
	}
	memset(mask, 255, n);
	for (size_t o = 8; o + 8 <= total; ) {
		const uint8_t *e = f + o; size_t el = be32(e + 4); if (el < 8 || o + el > total) break;
		if (!memcmp(e, LEGACY[legacy].mask, 4) && el - 8 >= n) { memcpy(mask, e + 8, n); break; }
		o += el;
	}
	if (!ok) { free(planes); free(mask); free(rgba); return 0; }
	for (size_t k = 0; k < n; k++) { rgba[k * 4] = planes[k]; rgba[k * 4 + 1] = planes[n + k]; rgba[k * 4 + 2] = planes[2 * n + k]; rgba[k * 4 + 3] = mask[k]; }
	free(planes); free(mask); out->rgba = rgba; return 1;
}
