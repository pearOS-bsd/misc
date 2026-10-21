#include "bvg.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* the tables of CSIBVGCoding (read from CoreUI) */
static const int W480[4] = { 4, 8, 12, 32 }, W484[4] = { 10, 14, 26, 38 }, W488[4] = { 12, 16, 28, 40 }, W538[2] = { 8, 12 };
static const int SMALL[16] = { 4, 6, 8, 10 }, LARGE[16] = { 8, 10, 12, 14 };

typedef struct { const uint8_t *d; size_t n, p; int ok; } Nib;     /* p counts nibbles, the high one first */

static int more(const Nib *r) { return r->p < r->n * 2; }
static unsigned nib(Nib *r) { if (r->p >= r->n * 2) { r->ok = 0; return 0; } unsigned b = r->d[r->p >> 1]; unsigned v = (r->p & 1) ? b & 15 : b >> 4; r->p++; return v; }
static unsigned peek(Nib *r) { if (r->p >= r->n * 2) { r->ok = 0; return 0; } unsigned b = r->d[r->p >> 1]; return (r->p & 1) ? b & 15 : b >> 4; }
static uint64_t val(Nib *r, int count) { uint64_t v = 0; for (int i = 0; i < count; i++) v = v << 4 | nib(r); return v; }
static unsigned byte(Nib *r) { return (unsigned)val(r, 2); }
static int digits(uint64_t m) { int n = 1; while (m >= 10) { m /= 10; n++; } return n; }

static double generic(Nib *r, unsigned cls)                       /* decodeGenericValue */
{
	unsigned n = nib(r); uint64_t base;
	if (!cls) base = n & 7; else { int w = W480[(n >> 1) & 3]; uint64_t v = val(r, w / 4); base = ((uint64_t)(n & 1) << w) | v; }
	double x = (double)base; if (!(n & 8)) return x;
	unsigned m = nib(r);
	if (!(m & 4)) {
		unsigned k = nib(r), t = m & 3; uint64_t mant; int adj = 0;
		if (t == 0) mant = k;
		else if (t == 2) { int w = W488[k & 3]; mant = val(r, w / 4); adj = (k >> 2) & 3; }
		else if (t == 1) { int w = W484[(k >> 2) & 3] - 2; mant = val(r, w / 4) | ((uint64_t)(k & 3) << w); }
		else { unsigned j = nib(r); int w = W484[(j >> 2) & 3] - 2; mant = val(r, w / 4) | ((uint64_t)(j & 3) << w); adj = (int)k; }
		if (mant) x += (double)mant / pow(10.0, digits(mant) + adj);
		if (!(m & 8)) return x;
	}
	unsigned p = nib(r); if (!(p & 4)) { r->ok = 0; return x; }
	int e = (int)val(r, W538[p & 1] / 4);
	return (p & 2) ? x / pow(10.0, e) : x * pow(10.0, e);
}

typedef struct { BvgSeg *s; int n, cap; double cx, cy, sx, sy, lcx, lcy; int lastc; /* 1 after C/S, 2 after Q/T */ } Path;
static void push(Path *P, char op, double a, double b, double c, double d, double e, double f)
{
	if (P->n == P->cap) { P->cap = P->cap ? P->cap * 2 : 64; P->s = realloc(P->s, (size_t)P->cap * sizeof *P->s); }
	BvgSeg *s = &P->s[P->n++]; s->op = op; s->p[0] = a; s->p[1] = b; s->p[2] = c; s->p[3] = d; s->p[4] = e; s->p[5] = f;
}
static void apply(Path *P, char L, const double *v, int nv)       /* the SVG semantics of the command letter (lower case = relative) */
{
	int rel = L >= 'a'; char U = rel ? (char)(L - 32) : L; int arity = U == 'M' || U == 'L' || U == 'T' ? 2 : U == 'C' ? 6 : U == 'S' || U == 'Q' ? 4 : U == 'H' || U == 'V' ? 1 : 0;
	if (U == 'Z') { push(P, 'Z', 0, 0, 0, 0, 0, 0); P->cx = P->sx; P->cy = P->sy; P->lastc = 0; return; }
	for (int i = 0; arity && i + arity <= nv; i += arity) {
		double ox = rel ? P->cx : 0, oy = rel ? P->cy : 0; const double *q = v + i;
		switch (U) {
		case 'M': if (i == 0) { push(P, 'M', ox + q[0], oy + q[1], 0, 0, 0, 0); P->sx = P->cx = ox + q[0]; P->sy = P->cy = oy + q[1]; } else { push(P, 'L', ox + q[0], oy + q[1], 0, 0, 0, 0); P->cx = ox + q[0]; P->cy = oy + q[1]; } P->lastc = 0; break;
		case 'L': push(P, 'L', ox + q[0], oy + q[1], 0, 0, 0, 0); P->cx = ox + q[0]; P->cy = oy + q[1]; P->lastc = 0; break;
		case 'H': push(P, 'L', ox + q[0], P->cy, 0, 0, 0, 0); P->cx = ox + q[0]; P->lastc = 0; break;
		case 'V': push(P, 'L', P->cx, oy + q[0], 0, 0, 0, 0); P->cy = oy + q[0]; P->lastc = 0; break;
		case 'C': push(P, 'C', ox + q[0], oy + q[1], ox + q[2], oy + q[3], ox + q[4], oy + q[5]); P->lcx = ox + q[2]; P->lcy = oy + q[3]; P->cx = ox + q[4]; P->cy = oy + q[5]; P->lastc = 1; break;
		case 'S': { double x1 = P->lastc == 1 ? 2 * P->cx - P->lcx : P->cx, y1 = P->lastc == 1 ? 2 * P->cy - P->lcy : P->cy;
			push(P, 'C', x1, y1, ox + q[0], oy + q[1], ox + q[2], oy + q[3]); P->lcx = ox + q[0]; P->lcy = oy + q[1]; P->cx = ox + q[2]; P->cy = oy + q[3]; P->lastc = 1; break; }
		case 'Q': case 'T': {
			double x1, y1, x, y;
			if (U == 'Q') { x1 = ox + q[0]; y1 = oy + q[1]; x = ox + q[2]; y = oy + q[3]; } else { x1 = P->lastc == 2 ? 2 * P->cx - P->lcx : P->cx; y1 = P->lastc == 2 ? 2 * P->cy - P->lcy : P->cy; x = ox + q[0]; y = oy + q[1]; }
			push(P, 'C', P->cx + 2.0 / 3 * (x1 - P->cx), P->cy + 2.0 / 3 * (y1 - P->cy), x + 2.0 / 3 * (x1 - x), y + 2.0 / 3 * (y1 - y), x, y);
			P->lcx = x1; P->lcy = y1; P->cx = x; P->cy = y; P->lastc = 2; break; }
		}
	}
}

/* one "d" blob (CSIBVGPathDecoder::createDecodedPath); returns 0 when the stream is not a path */
static int decode_path(const uint8_t *d, size_t n, Path *P)
{
	Nib r = { d, n, 0, 1 };
	if (byte(&r) != 0) return -1;
	val(&r, 4); val(&r, 4); if (!r.ok) return -1;
	int have = 0;
	while (more(&r)) {
		unsigned cmd = byte(&r); if (!r.ok) break;
		if (cmd > 0xef) return -1;
		unsigned hi = cmd >> 4;
		if (hi == 7) { apply(P, 'Z', NULL, 0); have = 0; continue; }
		unsigned p = cmd & 3, flag, cls = 0; uint64_t R = 1;
		if (p) { R = val(&r, (int)p); flag = byte(&r); }
		else { unsigned q = nib(&r); flag = 8 | ((q >> 2) & 3); cls = q & 3; }
		if (!r.ok) return -1;
		static const char CM[16] = { 0, 'C', 'S', 'Q', 'T', 'H', 'V', 'Z', 0, 'c', 's', 'q', 't', 'h', 'v', 0 };
		char L = hi == 0 ? (have ? 'L' : 'M') : hi == 8 ? (have ? 'l' : 'm') : CM[hi]; if (!L) return -1;
		have = 1;
		double vals[512]; int nv = 0; uint64_t g = 0;
		while (more(&r)) {
			if (flag & 4) cls = nib(&r);
			uint64_t cnt = (flag & 8) ? (flag >> 4) + 1 : val(&r, (int)(flag >> 4));
			double sx = (flag & 2) ? -1 : 1, sy = (flag & 1) ? -1 : 1; g++;
			for (uint64_t k = 0; k < cnt && r.ok; k++) {
				double x, y;
				if (!(cmd & 8)) { x = generic(&r, cls); y = generic(&r, cls); }
				else {
					unsigned pk = peek(&r); int bx = (pk & 8 ? LARGE : SMALL)[cls & 15], by = (pk & 4 ? LARGE : SMALL)[cls & 15];
					uint64_t raw = val(&r, (bx + by) >> 2);
					x = (double)((raw >> (by - 1)) & ((1ull << (bx - 1)) - 1)); y = (double)(raw & ((1ull << (by - 1)) - 1));
				}
				if (!r.ok) return -1;
				if (nv + 2 > 512) return -1;
				vals[nv++] = x ? x * sx : x; vals[nv++] = y ? y * sy : y;
			}
			if (g >= R) break;
			flag = byte(&r);
		}
		if (!r.ok) return -1;
		if (nv) { if (cmd & 4) nv--; apply(P, L, vals, nv); }
	}
	return 0;
}

int bvg_parse(const uint8_t *b, size_t len, BvgGlyph *g)
{
	memset(g, 0, sizeof *g); if (len < 16 || memcmp(b, "BVG ", 4)) return -1;
	int v11 = b[5] == 0x11;                                                                        /* version 0x11: the part count at 8 and one-byte offsets from 9; 0x12: count at 10, 16-bit offsets from 11 */
	int n = v11 ? b[8] : b[10]; if (n < 3 || (v11 ? 9 + (size_t)(n + 1) : 11 + 2 * (size_t)(n + 1)) > len) return -1;
	uint32_t off[40]; if (n >= 40) return -1;
	for (int i = 0; i <= n; i++) off[i] = v11 ? b[9 + i] : (uint32_t)(b[11 + 2 * i] | b[12 + 2 * i] << 8);
	for (int i = 0; i < n; i++) if (off[i] > off[i + 1] || off[i + 1] > len) return -1;
	int mi = -1; for (int i = 0; i < n; i++) if (off[i + 1] - off[i] > 7 && !memcmp(b + off[i], "matrix(", 7)) { mi = i; break; }
	if (mi < 0) return -1;
	char ms[160]; size_t ml = off[mi + 1] - off[mi]; if (ml >= sizeof ms) return -1; memcpy(ms, b + off[mi], ml); ms[ml] = 0;
	if (sscanf(ms, "matrix(%lf %lf %lf %lf %lf %lf", &g->m[0], &g->m[1], &g->m[2], &g->m[3], &g->m[4], &g->m[5]) != 6) return -1;
	Path P = { 0 }; double opacity = 1; BvgLayer *lay = NULL; int nl = 0, enc = 0;
	for (int i = mi + 1; i < n; i++) {
		const uint8_t *s = b + off[i]; size_t sl = off[i + 1] - off[i]; int text = sl > 0;
		for (size_t k = 0; k < sl; k++) if ((s[k] < 32 && !(k + 1 == sl && s[k] == 0)) || s[k] > 126) text = 0;
		if (text) { char t[32]; size_t m = sl < 31 ? sl : 31; memcpy(t, s, m); t[m] = 0; if (strchr(t, '.') && t[0] >= '0' && t[0] <= '9') opacity = atof(t); else if (!strncmp(t, "_enclosure.fill", 15)) enc = 1; continue; }
		if (sl < 3 || (s[1] & 0xc0)) continue;                                                    /* a numeric list (stroke data), not a path */
		int first = P.n; P.cx = P.cy = P.sx = P.sy = 0; P.lastc = 0;
		if (decode_path(s, sl, &P) || P.n == first) { P.n = first; continue; }
		lay = realloc(lay, (size_t)(nl + 1) * sizeof *lay); lay[nl].first = first; lay[nl].count = P.n - first; lay[nl].opacity = opacity; lay[nl].knockout = enc == 2; if (enc == 1) enc = 2; nl++; opacity = 1;
	}
	if (!P.n) { free(P.s); free(lay); return -1; }
	for (int i = 0; i < P.n; i++) {                                                                  /* through the matrix */
		BvgSeg *s = &P.s[i]; int np = s->op == 'C' ? 3 : s->op == 'Z' ? 0 : 1;
		for (int k = 0; k < np; k++) { double x = s->p[2 * k], y = s->p[2 * k + 1]; s->p[2 * k] = g->m[0] * x + g->m[2] * y + g->m[4]; s->p[2 * k + 1] = g->m[1] * x + g->m[3] * y + g->m[5]; }
	}
	g->seg = P.s; g->nseg = P.n; g->layer = lay; g->nlayer = nl; return 0;
}
void bvg_free(BvgGlyph *g) { free(g->seg); free(g->layer); memset(g, 0, sizeof *g); }
