#include "ws_region.h"
#include <stdlib.h>
#include <string.h>

#define MAGIC 0x80000000u
#define VERSION 2u
#define END 0x7fffffff

static int32_t rd(const uint8_t *b, size_t i) { int32_t v; memcpy(&v, b + i * 4, 4); return v; }
static void wr(uint8_t *b, size_t i, int32_t v) { memcpy(b + i * 4, &v, 4); }

int ws_region_parse(const uint8_t *b, uint32_t len, ws_rect **rects, int *nrects, ws_rect *bounds)
{
	*rects = NULL; *nrects = 0; *bounds = (ws_rect){ 0, 0, 0, 0 };
	if (len < 12 || (len & 3)) return -1;
	size_t nw = len / 4, i = 0;
	if ((uint32_t)rd(b, i++) != MAGIC || (uint32_t)rd(b, i++) != VERSION) return -1;
	int32_t y = rd(b, i++);
	if (y == END) return nw == 3 ? 0 : -1;               /* empty region */
	ws_rect *out = NULL; int n = 0, cap = 0;
	int32_t minx = END, miny = y, maxx = -END, maxy = y;
	for (;;) {
		if (i >= nw) goto bad;
		int32_t cnt = rd(b, i++);
		if (cnt < 2 || (cnt & 1) || (size_t)(cnt - 2) + 1 > nw - i) goto bad;
		int runs = (cnt - 2) / 2;
		size_t xs = i; i += (size_t)(cnt - 2);
		int32_t ynext = rd(b, i++);
		if (cnt == 2 && ynext == END) { if (i != nw) goto bad; break; }
		if (ynext <= y) goto bad;
		for (int k = 0; k < runs; k++) {
			int32_t x0 = rd(b, xs + 2 * k), x1 = rd(b, xs + 2 * k + 1);
			if (x1 <= x0) goto bad;
			if (n == cap) {
				if (cap >= WS_REGION_MAX_RECTS) goto bad;
				cap = cap ? cap * 2 : 8;
				ws_rect *nr = realloc(out, (size_t)cap * sizeof *nr);
				if (!nr) goto bad;
				out = nr;
			}
			out[n++] = (ws_rect){ x0, y, x1 - x0, ynext - y };
			if (x0 < minx) minx = x0;
			if (x1 > maxx) maxx = x1;
		}
		y = ynext; maxy = ynext;
	}
	if (n == 0) { free(out); return -1; }
	*rects = out; *nrects = n; *bounds = (ws_rect){ minx, miny, maxx - minx, maxy - miny };
	return 0;
bad:
	free(out);
	return -1;
}

static int cmp_int(const void *a, const void *b) { int x = *(const int *)a, y = *(const int *)b; return (x > y) - (x < y); }

size_t ws_region_serialize(const ws_rect *r, int n, uint8_t *out, size_t cap)
{
	size_t w = 0;
#define PUT(v) do { if ((w + 1) * 4 > cap) return 0; wr(out, w++, (int32_t)(v)); } while (0)
	PUT(MAGIC); PUT(VERSION);
	int live = 0;
	for (int i = 0; i < n; i++) if (r[i].w > 0 && r[i].h > 0) live++;
	if (!live) { PUT(END); return w * 4; }
	int *ys = malloc((size_t)live * 2 * sizeof *ys), ny = 0;
	if (!ys) return 0;
	for (int i = 0; i < n; i++) if (r[i].w > 0 && r[i].h > 0) { ys[ny++] = r[i].y; ys[ny++] = r[i].y + r[i].h; }
	qsort(ys, (size_t)ny, sizeof *ys, cmp_int);
	int u = 0;
	for (int i = 0; i < ny; i++) if (!u || ys[i] != ys[u - 1]) ys[u++] = ys[i];
	/* per slab [ys[k], ys[k+1]): union of x intervals; merge slabs with identical runs */
	int32_t *prev = NULL; int prev_n = 0; int started = 0;
	int32_t *cur = malloc((size_t)live * 2 * sizeof *cur);
	int *ix = malloc((size_t)live * 2 * sizeof *ix);
	prev = malloc((size_t)live * 2 * sizeof *prev);
	if (!cur || !ix || !prev) { free(ys); free(cur); free(ix); free(prev); return 0; }
	int top = 0;
	for (int k = 0; k + 1 < u; k++) {
		int m = 0;
		for (int i = 0; i < n; i++)
			if (r[i].w > 0 && r[i].h > 0 && r[i].y <= ys[k] && r[i].y + r[i].h >= ys[k + 1]) { ix[2 * m] = r[i].x; ix[2 * m + 1] = r[i].x + r[i].w; m++; }
		/* sort intervals by start and merge overlapping or touching ones */
		for (int a = 1; a < m; a++) { int s = ix[2 * a], e = ix[2 * a + 1], b = a - 1; while (b >= 0 && ix[2 * b] > s) { ix[2 * b + 2] = ix[2 * b]; ix[2 * b + 3] = ix[2 * b + 1]; b--; } ix[2 * b + 2] = s; ix[2 * b + 3] = e; }
		int cn = 0;
		for (int a = 0; a < m; a++) {
			if (cn && ix[2 * a] <= cur[cn - 1]) { if (ix[2 * a + 1] > cur[cn - 1]) cur[cn - 1] = ix[2 * a + 1]; }
			else { cur[cn++] = ix[2 * a]; cur[cn++] = ix[2 * a + 1]; }
		}
		if (started && cn == prev_n && memcmp(cur, prev, (size_t)cn * sizeof *cur) == 0) continue;   /* same runs: band continues */
		if (started && prev_n) { /* close the previous band at this slab's top */ PUT(ys[k]); }
		else if (started && !prev_n) { PUT(ys[k]); }
		if (!started) { if (cn == 0) continue; PUT(ys[k]); started = 1; top = ys[k]; }
		(void)top;
		PUT(2 + cn); for (int a = 0; a < cn; a++) PUT(cur[a]);
		memcpy(prev, cur, (size_t)cn * sizeof *cur); prev_n = cn;
	}
	PUT(ys[u - 1]); PUT(2); PUT(END);
	free(ys); free(cur); free(ix); free(prev);
	return w * 4;
#undef PUT
}
