/* wscarender: the CoreAnimation scene of the commits that carender-stub keeps (ca.bin + ca-ool-<n>-<k>.bin), composed and shown in a window of wsd.
 * It is the C port of darwinator/tools/ca/{caparse,ca_scene}.py: decode the command stream of the render server protocol (messages 0x9c42..0x9c45), follow the layers,
 * give every Image its pixels from the out-of-line data, paint the tree.  A client of wsd for now; the decoder and the painter (everything above main) are meant to move into the
 * render server of wsd (CARenderServer) when it takes the commits itself.
 *
 *   usage: wscarender CADIR [x y [level [w h]]]        (CADIR holds ca.bin and the ca-ool files; reloads when ca.bin grows)
 *
 * Painted: background colour and opacity, Image contents (BGRA8 or RGBA half float, first plane), children on top.  Not yet: transforms, masks, filters, object types 2/3/25/160. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <sys/stat.h>
#include "ws_client.h"

/* ---- reader ---- */
typedef struct { const uint8_t *b; size_t n, p; int err; } rd;
static uint8_t u8(rd *r) { if (r->p + 1 > r->n) { r->err = 1; return 0; } return r->b[r->p++]; }
static uint16_t u16(rd *r) { uint16_t v = 0; if (r->p + 2 > r->n) { r->err = 1; return 0; } memcpy(&v, r->b + r->p, 2); r->p += 2; return v; }
static uint32_t u32(rd *r) { uint32_t v = 0; if (r->p + 4 > r->n) { r->err = 1; return 0; } memcpy(&v, r->b + r->p, 4); r->p += 4; return v; }
static uint64_t u64(rd *r) { uint64_t v = 0; if (r->p + 8 > r->n) { r->err = 1; return 0; } memcpy(&v, r->b + r->p, 8); r->p += 8; return v; }
static const uint8_t *raw(rd *r, size_t k) { const uint8_t *p = r->b + r->p; if (k > r->n || r->p + k > r->n) { r->err = 1; return NULL; } r->p += k; return p; }

/* ---- the scene ---- */
#define MAXL 4096
#define MAXS 64
typedef struct { int w, h, bpp; uint8_t *px; } img_t;
typedef struct {
	uint64_t id;
	int used;
	double px_, py_, w, h;
	float col[5];
	int any_col;
	uint64_t subs[MAXS]; int nsubs;
	uint64_t img;		/* id of the Image object, 0: none */
} layer_t;
static layer_t L[MAXL]; static int nL;
typedef struct { uint64_t id; img_t im; } imgent_t;
static imgent_t IM[MAXL]; static int nIM;
static const char *cadir;

static layer_t *find(uint64_t id) { for (int i = 0; i < nL; i++) if (L[i].used && L[i].id == id) return &L[i]; return NULL; }
static layer_t *get(uint64_t id) { layer_t *l = find(id); if (l) return l; for (int i = 0; i < nL; i++) if (!L[i].used) { l = &L[i]; goto init; } if (nL >= MAXL) return NULL; l = &L[nL++]; init: memset(l, 0, sizeof *l); l->used = 1; l->id = id; return l; }
static void setimg(uint64_t id, img_t *im) { for (int i = 0; i < nIM; i++) if (IM[i].id == id) { free(IM[i].im.px); IM[i].im = *im; return; } if (nIM < MAXL) { IM[nIM].id = id; IM[nIM].im = *im; nIM++; } }
static img_t *getimg(uint64_t id) { for (int i = 0; i < nIM; i++) if (IM[i].id == id) return &IM[i].im; return NULL; }

/* ---- decoder ---- */
typedef struct { int kind; uint64_t id; int attached; int w, h, bpp; uint64_t imgid; } contents_t;	/* kind: 0 none, 1 image, 2 reference */
static int cur_ool_msg;			/* the file number of the message being read, or -1 */
static int ool_desc[32], n_ool;		/* descriptor indexes of its out-of-line data */
static int ool_taken;

static void skip_obj(rd *r, int depth, contents_t *ct);
static void skip_arr(rd *r, int depth, uint64_t *ids, int *nids)
{
	if (!u8(r)) return;
	uint32_t fl = u32(r), n = u32(r);
	if (fl & 1) { for (uint32_t i = 0; i < n && !r->err; i++) { uint64_t v = u64(r); if (ids && *nids < MAXS) ids[(*nids)++] = v; } }
	else for (uint32_t i = 0; i < n && !r->err; i++) skip_obj(r, depth + 1, NULL);
}
static void skip_atom(rd *r) { uint8_t b = u8(r); if (b < 0xfe) return; if (b == 0xfe) { u16(r); return; } uint64_t n = u64(r); raw(r, n); }
static void skip_cf(rd *r, int depth)
{
	uint8_t t = u8(r);
	if (depth > 20) { r->err = 1; return; }
	switch (t) {
	case 1: break;
	case 2: if (u8(r)) { uint64_t n = u64(r); raw(r, n); } break;
	case 3: u8(r); u64(r); break;
	case 4: u8(r); break;
	case 5: { uint64_t n = u64(r); if (n != 0xffffffffULL && n != ~0ULL) raw(r, n); break; }
	case 6: { uint64_t n = u64(r); for (uint64_t i = 0; i < n && !r->err; i++) skip_cf(r, depth + 1); break; }
	case 7: { uint64_t n = u64(r); for (uint64_t i = 0; i < n && !r->err; i++) { skip_cf(r, depth + 1); skip_cf(r, depth + 1); } break; }
	default: r->err = 1;
	}
}
static void do_layer(rd *r, int depth, uint64_t id);
static void skip_obj(rd *r, int depth, contents_t *ct)
{
	if (depth > 40) { r->err = 1; return; }
	uint8_t t = u8(r);
	if (r->err) return;
	switch (t) {
	case 0: break;
	case 0xff: { uint64_t i = u64(r); u32(r); if (ct) { ct->kind = 2; ct->imgid = i; } break; }
	case 0xfe: { uint64_t i = u64(r); u32(r); contents_t in; memset(&in, 0, sizeof in); skip_obj(r, depth + 1, &in); if (ct) { *ct = in; ct->imgid = i; } break; }
	case 0x1e: do_layer(r, depth, 0); break;		/* a layer inside an object: decoded, not kept */
	case 0x36: { uint32_t n = u32(r); raw(r, n); break; }
	case 0x3e: { uint32_t n = u32(r); raw(r, 8ULL * n); break; }
	case 0x34: { uint32_t fl = u32(r); if ((fl & 3) == 0) { uint64_t n = u64(r); if (n != 0xffffffffULL && n != ~0ULL) raw(r, n); else if (ct) ct->attached = 1; } else { u64(r); u64(r); } break; }
	case 0x12: { uint32_t fl = u32(r); if ((fl >> 8) & 1) skip_atom(r); else { if (u8(r) != 1) { r->err = 1; break; } skip_atom(r); skip_obj(r, depth + 1, NULL); skip_arr(r, depth, NULL, NULL); } break; }
	case 0x17: {
		u32(r); uint8_t fmt = u8(r); uint8_t np = u8(r); uint32_t w = u32(r), h = u32(r); uint64_t row0 = 0;
		(void)fmt;
		for (int i = 0; i < np && !r->err; i++) { uint64_t v = u64(r); if (i == 0) row0 = v; }
		if (u8(r)) { contents_t in; memset(&in, 0, sizeof in); skip_obj(r, depth + 1, &in); if (ct) { ct->kind = 1; ct->attached = in.attached; } }
		else { uint64_t n = u64(r); if (n != 0xffffffffULL && n != ~0ULL) raw(r, n); else if (ct) { ct->kind = 1; ct->attached = 1; } }
		if (ct) { ct->kind = 1; ct->w = (int)w; ct->h = (int)h; ct->bpp = w ? (int)(row0 / w) : 4; }
		break; }
	case 0x1f: u32(r); u32(r); u8(r); break;
	default: r->err = 1;
	}
}
static void do_layer(rd *r, int depth, uint64_t id)
{
	u32(r);
	const uint8_t *pod = raw(r, 0x58);
	contents_t ct; memset(&ct, 0, sizeof ct);
	skip_obj(r, depth + 1, &ct);
	if (r->err) return;
	if (ct.kind) { uint8_t cb = u8(r); raw(r, 24 + ((cb & 0x20) ? 3 : 0)); }
	uint64_t subs[MAXS]; int ns = 0, hassubs = 0;
	{ size_t p0 = r->p; skip_arr(r, depth, subs, &ns); hassubs = r->p > p0 + 1; }
	u64(r); skip_obj(r, depth + 1, NULL);
	uint8_t ext = u8(r);
	if (ext) {
		for (int i = 0; i < 1 + 6 + 1 + 4; i++) skip_obj(r, depth + 1, NULL);
		skip_arr(r, depth, NULL, NULL); skip_arr(r, depth, NULL, NULL);
		for (int i = 0; i < 3; i++) skip_obj(r, depth + 1, NULL);
		skip_arr(r, depth, NULL, NULL);
		skip_obj(r, depth + 1, NULL); skip_obj(r, depth + 1, NULL);
		skip_arr(r, depth, NULL, NULL);
		raw(r, 16); raw(r, 16); u64(r); u64(r); raw(r, 0x14); raw(r, 8);
		for (int i = 0; i < 4; i++) u32(r);
		raw(r, 0x14); for (int i = 0; i < 5; i++) u32(r);
		raw(r, 0x14); for (int i = 0; i < 5; i++) u32(r);
		raw(r, 0x14); u32(r); u64(r); skip_obj(r, depth + 1, NULL); skip_obj(r, depth + 1, NULL); u8(r);
	}
	if (r->err || id == 0 || pod == NULL) return;
	layer_t *l = get(id);
	if (!l) return;
	double d[6]; memcpy(d, pod + 0x28, sizeof d);
	float col[5]; memcpy(col, pod, sizeof col);
	l->px_ = d[0]; l->py_ = d[1]; l->w = d[4]; l->h = d[5];
	memcpy(l->col, col, sizeof col);
	l->any_col = col[0] != 0 || col[1] != 0 || col[2] != 0 || col[3] != 0 || col[4] != 0;
	if (hassubs) { l->nsubs = ns; memcpy(l->subs, subs, sizeof(uint64_t) * ns); }
	if (ct.kind) {
		l->img = ct.imgid;
		if (ct.kind == 1 && ct.attached && cur_ool_msg >= 0 && ool_taken < n_ool) {
			char nm[512]; snprintf(nm, sizeof nm, "%s/ca-ool-%02d-%d.bin", cadir, cur_ool_msg, ool_desc[ool_taken++]);
			FILE *f = fopen(nm, "rb");
			if (f) {
				fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
				img_t im; im.w = ct.w; im.h = ct.h; im.bpp = ct.bpp; im.px = malloc(sz > 0 ? sz : 1);
				if (im.px && fread(im.px, 1, sz, f) == (size_t)sz && sz >= (long)ct.w * ct.h * ct.bpp) setimg(ct.imgid, &im); else free(im.px);
				fclose(f);
			}
		}
	}
}

static void message(const uint8_t *m, size_t n, int *nmsg)
{
	if (n < 0x1c) return;
	uint32_t bits; memcpy(&bits, m, 4);
	size_t st = 0x1c;
	n_ool = 0; ool_taken = 0; cur_ool_msg = -1;
	if (bits & 0x80000000u) {
		uint32_t nd; memcpy(&nd, m + 0x18, 4);
		for (uint32_t i = 0; i < nd && st + 12 <= n; i++) {
			if (st + 12 <= n && m[st + 11] == 1) { if (n_ool < 32) ool_desc[n_ool++] = (int)i; st += 16; } else st += 12;
		}
		cur_ool_msg = (*nmsg)++;
	}
	rd r = { m + st, n - st, 0, 0 };
	u32(&r); u32(&r); u64(&r);
	while (!r.err && r.p < r.n) {
		uint8_t op = u8(&r);
		if (op == 0) break;
		else if (op == 1) { uint64_t id = u64(&r); u32(&r); layer_t *l = find(id); if (l) l->used = 0; }
		else if (op == 2) { uint64_t id = u64(&r); u32(&r); uint8_t t = r.b[r.p < r.n ? r.p : 0]; if (t == 0x1e) { r.p++; do_layer(&r, 0, id); } else skip_obj(&r, 0, NULL); u32(&r); }
		else if (op == 3 || op == 7 || op == 0x1a || op == 0x1c || op == 0x1d || op == 0x1e || op == 0xb || op == 0xc) u64(&r);
		else if (op == 9) { u8(&r); u8(&r); }
		else if (op == 8 || op == 10) skip_cf(&r, 0);
		else if (op == 0xd) u32(&r);
		else if (op == 0x20) { u32(&r); u8(&r); }
		else if (op == 0x25) ;
		else if (op == 0x1f) u8(&r);
		else break;
	}
}

static int load_stream(const char *path)
{
	FILE *f = fopen(path, "rb");
	if (!f) return -1;
	fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
	uint8_t *d = malloc(sz + 1);
	if (!d || fread(d, 1, sz, f) != (size_t)sz) { fclose(f); free(d); return -1; }
	fclose(f);
	memset(L, 0, sizeof L); nL = 0;
	for (int i = 0; i < nIM; i++) free(IM[i].im.px);
	nIM = 0;
	int nmsg = 0;
	for (long p = 0; p + 4 <= sz;) {
		uint32_t n; memcpy(&n, d + p, 4); p += 4;
		if (p + n > (unsigned long)sz) break;
		message(d + p, n, &nmsg);
		p += n;
	}
	free(d);
	return 0;
}

/* ---- painter ---- */
static float half(uint16_t h)
{
	uint32_t s = (h >> 15) & 1, e = (h >> 10) & 31, m = h & 1023, o;
	if (e == 0) { if (m == 0) o = s << 31; else { e = 1; while (!(m & 1024)) { m <<= 1; e--; } m &= 1023; o = (s << 31) | ((e + 112) << 23) | (m << 13); } }
	else if (e == 31) o = (s << 31) | 0x7f800000 | (m << 13);
	else o = (s << 31) | ((e + 112) << 23) | (m << 13);
	float f; memcpy(&f, &o, 4); return f;
}
static void blend(ws_win *win, int x, int y, int r, int g, int b, int a)
{
	if (x < 0 || y < 0 || x >= win->px->w || y >= win->px->h || a <= 0) return;
	uint8_t *p = win->px->px + (size_t)y * win->px->stride + x * 4;
	if (a > 255) a = 255;
	p[0] = (uint8_t)((p[0] * (255 - a) + b * a) / 255); p[1] = (uint8_t)((p[1] * (255 - a) + g * a) / 255); p[2] = (uint8_t)((p[2] * (255 - a) + r * a) / 255); p[3] = 255;
}
static void paint_layer(ws_win *win, uint64_t id, double ox, double oy, double op, int depth)
{
	layer_t *l = find(id);
	int H = win->px->h;
	if (!l || depth > 64) return;
	double x = ox + l->px_ - l->w / 2, y = oy + l->py_ - l->h / 2, o = l->any_col ? l->col[4] : 1.0, a = l->any_col ? l->col[3] : 0.0;
	double op2 = op * (o > 0 ? (o > 1 ? 1 : o) : 0);
	if (l->w > 0 && l->h > 0 && op2 > 0) {
		int bx = (int)x, by = (int)(H - (y + l->h)), iw = (int)l->w, ih = (int)l->h;
		if (a > 0)
			for (int j = 0; j < ih; j++) for (int i = 0; i < iw; i++)
				blend(win, bx + i, by + j, (int)(l->col[0] * 255), (int)(l->col[1] * 255), (int)(l->col[2] * 255), (int)(a * op2 * 255));
		img_t *im = l->img ? getimg(l->img) : NULL;
		if (im && im->w > 0 && im->h > 0)
			for (int j = 0; j < ih; j++) for (int i = 0; i < iw; i++) {
				int sx = (int)((i + 0.5) * im->w / iw), sy = (int)((j + 0.5) * im->h / ih), r, g, b, al;
				if (sx >= im->w) sx = im->w - 1;
				if (sy >= im->h) sy = im->h - 1;
				if (im->bpp == 8) {
					const uint16_t *s = (const uint16_t *)im->px + ((size_t)sy * im->w + sx) * 4;
					float fr = half(s[0]), fg = half(s[1]), fb = half(s[2]), fa = half(s[3]);
					#define CL(v) ((v) != (v) ? 0 : (v) < 0 ? 0 : (v) > 1 ? 255 : (int)((v) * 255))
					r = CL(fr); g = CL(fg); b = CL(fb); al = CL(fa);
				} else {
					const uint8_t *s = im->px + ((size_t)sy * im->w + sx) * 4;
					b = s[0]; g = s[1]; r = s[2]; al = s[3];
				}
				blend(win, bx + i, by + j, r, g, b, (int)(al * op2));
			}
	}
	for (int i = 0; i < l->nsubs; i++) paint_layer(win, l->subs[i], x, y, op2 > 0 ? op2 : op, depth + 1);
}
static void paint(ws_win *win)
{
	int W = win->px->w, H = win->px->h;
	uint64_t roots[MAXL]; int nr = 0;
	for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) { uint8_t *p = win->px->px + (size_t)j * win->px->stride + i * 4; p[0] = 30; p[1] = 28; p[2] = 28; p[3] = 255; }
	for (int i = 0; i < nL; i++) {
		int child = 0;
		if (!L[i].used) continue;
		for (int k = 0; k < nL && !child; k++) if (L[k].used) for (int s = 0; s < L[k].nsubs; s++) if (L[k].subs[s] == L[i].id) { child = 1; break; }
		if (!child && nr < MAXL) roots[nr++] = L[i].id;
	}
	for (int i = 0; i < nr; i++) for (int k = i + 1; k < nr; k++) {		/* the biggest root first: the back */
		layer_t *a = find(roots[i]), *b = find(roots[k]);
		if (b->w * b->h > a->w * a->h) { uint64_t t = roots[i]; roots[i] = roots[k]; roots[k] = t; }
	}
	for (int i = 0; i < nr; i++) paint_layer(win, roots[i], 0, 0, 1.0, 0);
}

int main(int argc, char **argv)
{
	int x = argc > 3 ? atoi(argv[2]) : 0, y = argc > 3 ? atoi(argv[3]) : 0, level = argc > 4 ? atoi(argv[4]) : 0, w = argc > 6 ? atoi(argv[5]) : 1280, h = argc > 6 ? atoi(argv[6]) : 800;
	char path[512]; off_t last = -1;
	ws_win win; ws_conn *c;

	if (argc < 2) { fprintf(stderr, "usage: wscarender CADIR [x y [level [w h]]]\n"); return 1; }
	cadir = argv[1]; snprintf(path, sizeof path, "%s/ca.bin", cadir);
	if ((c = ws_connect(NULL)) == NULL) { fprintf(stderr, "wscarender: cannot connect to wsd\n"); return 1; }
	if (ws_win_create(c, (ws_rect){ x, y, w, h }, level, &win)) { fprintf(stderr, "wscarender: cannot create the window\n"); return 1; }
	ws_win_order(c, &win, WS_ABOVE, 0);
	for (;;) {
		struct stat st;
		if (stat(path, &st) == 0 && st.st_size != last) {
			if (load_stream(path) == 0) {
				paint(&win); ws_win_flush(c, &win);
				fprintf(stderr, "wscarender: %ld bytes, %d layers, %d images\n", (long)st.st_size, nL, nIM);
				last = st.st_size;
			}
		}
		usleep(500000);
	}
}
