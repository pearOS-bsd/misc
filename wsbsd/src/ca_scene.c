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
#include "ca_scene.h"

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
typedef struct { uint64_t id; img_t im; } imgent_t;
#define MAXSCENES 16
#define MAXROOTS 16
struct scene { layer_t layers[MAXL]; int nlayers; imgent_t images[MAXL]; int nimages; int nskipped; uint32_t ctx; int nroots; uint32_t rootctx[MAXROOTS]; uint64_t rootid[MAXROOTS]; };		/* rootctx/rootid: the root layer of each render context (op 7 of its first commit) */
static struct scene *S, *scenes[MAXSCENES]; static int nscenes;		/* S: the scene that is being fed or painted */
#define L (S->layers)
#define nL (S->nlayers)
#define IM (S->images)
#define nIM (S->nimages)
#define skipped (S->nskipped)
static const char *cadir = ".";
static uint8_t *file_ool(void *ctx, int msg, int desc, size_t *sz)
{
	char nm[512]; snprintf(nm, sizeof nm, "%s/ca-ool-%02d-%d.bin", cadir, msg, desc);
	FILE *f = fopen(nm, "rb"); long n; uint8_t *p;
	(void)ctx;
	if (!f) return NULL;
	fseek(f, 0, SEEK_END); n = ftell(f); fseek(f, 0, SEEK_SET);
	p = malloc(n > 0 ? n : 1);
	if (!p || fread(p, 1, n, f) != (size_t)n) { free(p); fclose(f); return NULL; }
	fclose(f); *sz = (size_t)n; return p;
}
static ca_ool_fn ool_loader = file_ool;
static void *ool_ctx;
void ca_set_dir(const char *d) { cadir = d; }
void ca_set_ool_loader(ca_ool_fn fn, void *ctx) { ool_loader = fn ? fn : file_ool; ool_ctx = ctx; }
int ca_nlayers(void) { int n = 0; for (int i = 0; i < nscenes; i++) n += scenes[i]->nlayers; return n; }
int ca_nimages(void) { int n = 0; for (int i = 0; i < nscenes; i++) n += scenes[i]->nimages; return n; }
int ca_nscenes(void) { return nscenes; }
void ca_scene_info(int i, int *nlayers, int *nimages) { *nlayers = i >= 0 && i < nscenes ? scenes[i]->nlayers : 0; *nimages = i >= 0 && i < nscenes ? scenes[i]->nimages : 0; }
uint32_t ca_scene_ctx(int i) { return i >= 0 && i < nscenes ? scenes[i]->ctx : 0; }

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
	default: if (getenv("CA_DEBUG")) fprintf(stderr, "ca_scene: unknown object type %#x at %zu\n", t, r->p - 1); r->err = 1;
	}
}
static void do_layer(rd *r, int depth, uint64_t id);
/* CA::Render::Texture::decode (the end of an Image): colorspace, i32, 4 x i16, shape, i32, i32, and 0x14 bytes when the Image flags say so (decompilation of QuartzCore) */
static void texture_tail(rd *r, uint32_t image_flags)
{
	uint8_t cs = u8(r);
	switch (cs) {
	case 0: case 3: break;
	case 1: u8(r); break;
	case 2: case 4: skip_cf(r, 0); break;
	default: r->err = 1; return;
	}
	u32(r); for (int i = 0; i < 4; i++) u16(r);
	{	/* the shape: -2 bounds (4 x i32), 0 none, -1 all, else a list of n words (3 are the header) */
		int32_t n = (int32_t)u32(r);
		if (n == -2) { for (int i = 0; i < 4; i++) u32(r); }
		else if (n != 0 && n != -1) { if (n < 3 || n > 0x20000) { r->err = 1; return; } raw(r, (size_t)(n - 3) * 4); }
	}
	u32(r); u32(r);
	if (image_flags & 0x1000) raw(r, 0x14);
}
static void skip_obj_(rd *r, int depth, contents_t *ct);
static void skip_obj(rd *r, int depth, contents_t *ct)
{
	size_t p0 = r->p; int e0 = r->err;
	skip_obj_(r, depth, ct);
	if (!e0 && r->err && getenv("CA_DEBUG")) fprintf(stderr, "ca_scene: object at %zu (type %#x) failed at %zu (depth %d)\n", p0, p0 < r->n ? r->b[p0] : 0, r->p, depth);
}
static void skip_obj_(rd *r, int depth, contents_t *ct)
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
	case 0x12: { uint32_t fl = u32(r); if ((fl >> 8) & 1) skip_atom(r); else { { uint8_t kind = u8(r); if (kind == 0) { skip_cf(r, 0); break; } if (kind != 1) { r->err = 1; break; } } skip_atom(r); skip_obj(r, depth + 1, NULL); skip_arr(r, depth, NULL, NULL); } break; }
	case 0x17: {
		uint32_t flags_i = u32(r); uint8_t fmt = u8(r); uint8_t np = u8(r); uint32_t w = u32(r), h = u32(r); uint64_t row0 = 0;
		(void)fmt;
		for (int i = 0; i < np && !r->err; i++) { uint64_t v = u64(r); if (i == 0) row0 = v; }
		if (u8(r)) { contents_t in; memset(&in, 0, sizeof in); skip_obj(r, depth + 1, &in); if (ct) { ct->kind = 1; ct->attached = in.attached; } }
		else { uint64_t n = u64(r); if (n != 0xffffffffULL && n != ~0ULL) raw(r, n); else if (ct) { ct->kind = 1; ct->attached = 1; } }
		texture_tail(r, flags_i);
		if (ct) { ct->kind = 1; ct->w = (int)w; ct->h = (int)h; ct->bpp = w ? (int)(row0 / w) : 4; }
		break; }
	case 0x1f: u32(r); u32(r); u8(r); break;
	/* the formats below come from the decompilation of QuartzCore (CA::Render::<Class>::<Class>(Decoder*), REA/Ghidra) */
	case 3: {		/* BackdropLayer: Object flags, vm_size_t, String, 4 x i32, 0x20 bytes, i32, 0x20 bytes, i8 enum */
		u32(r); u64(r); skip_obj(r, depth + 1, NULL);
		for (int i = 0; i < 4; i++) u32(r);
		raw(r, 0x20); u32(r); raw(r, 0x20); u8(r); break; }
	case 0x1d: skip_atom(r); skip_obj(r, depth + 1, NULL); break;		/* KeyValue: atom, any object (no Object flags) */
	case 0x3a: u32(r); u32(r); for (int i = 0; i < 5; i++) u64(r); break;	/* Timing: Object flags, i32, 5 x i64 */
	case 0x3f:		/* WindowLayer: Object flags, vm_size_t, i64, i8 enum */
		u32(r); u64(r); u64(r); u8(r); break;
	case 0x19:		/* ImageQueue::decode: Shmem, i32, (a port: no bytes), i32, i32 */
		skip_obj(r, depth + 1, NULL); u32(r); u32(r); u32(r); break;
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
	uint64_t subs[MAXS]; int ns = 0, hassubs = 0;
	{ size_t p0 = r->p; skip_arr(r, depth, subs, &ns); hassubs = r->p > p0 + 1; }
	u64(r); skip_obj(r, depth + 1, NULL);
	if (r->err) return;
	if (id == 0 || pod == NULL) return;
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
			size_t sz = 0;
			uint8_t *px = ool_loader(ool_ctx, cur_ool_msg, ool_desc[ool_taken++], &sz);
			if (px) {
				img_t im; im.w = ct.w; im.h = ct.h; im.bpp = ct.bpp; im.px = px;
				if (sz >= (size_t)ct.w * ct.h * ct.bpp) setimg(ct.imgid, &im); else free(px);
			}
		}
	}
	{
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
	}
}

int ca_resynced(void) { int n = 0; for (int i = 0; i < nscenes; i++) n += scenes[i]->nskipped; return n; }
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
	u32(&r); uint32_t msg_ctx = u32(&r); u64(&r);
	while (!r.err && r.p < r.n) {
		uint8_t op = u8(&r);
		if (op == 0) break;
		else if (op == 1) { uint64_t id = u64(&r); u32(&r); layer_t *l = find(id); if (l) l->used = 0; }
		else if (op == 2) {
			size_t start = r.p;
			uint64_t id = u64(&r); u32(&r); uint8_t t = r.b[r.p < r.n ? r.p : 0];
			if (t == 0x1e) { r.p++; do_layer(&r, 0, id); } else skip_obj(&r, 0, NULL);
			u32(&r);
			if (r.err) {		/* an object that is not decoded yet (types 3, 25, 63, 160...): go on at the next layer record (02 + id + generation + 0x1e) */
				size_t q;
				for (q = start + 1; q + 14 <= r.n; q++)
					if (r.b[q] == 0x02 && r.b[q + 11] == 0 && r.b[q + 12] == 0 && r.b[q + 13] == 0x1e) break;
				if (q + 14 > r.n) break;
				if (getenv("CA_DEBUG")) fprintf(stderr, "ca_scene: record at %zu failed at %zu (id %llx), next record at %zu of %zu\n", start, r.p, (unsigned long long)id, q, r.n);
				r.err = 0; r.p = q; skipped++;
			}
		}
		else if (op == 7) {			/* the root layer of the context */
			uint64_t rid = u64(&r); int k;
			for (k = 0; k < S->nroots; k++) if (S->rootctx[k] == msg_ctx) break;
			if (k < MAXROOTS) { S->rootctx[k] = msg_ctx; S->rootid[k] = rid; if (k == S->nroots) S->nroots++; }
		}
		else if (op == 3 || op == 0x1a || op == 0x1c || op == 0x1d || op == 0x1e || op == 0xb || op == 0xc) u64(&r);
		else if (op == 9) { u8(&r); u8(&r); }
		else if (op == 8 || op == 10) skip_cf(&r, 0);
		else if (op == 0xd) u32(&r);
		else if (op == 0x20) { u32(&r); u8(&r); }
		else if (op == 0x25) ;
		else if (op == 0x1f) u8(&r);
		else break;
	}
}

static int g_nmsg;		/* complex messages fed so far: the number of the out-of-line data of the next one */
void ca_reset(void)
{
	for (int k = 0; k < nscenes; k++) {
		for (int i = 0; i < scenes[k]->nimages; i++) free(scenes[k]->images[i].im.px);
		free(scenes[k]); scenes[k] = NULL;
	}
	nscenes = 0; S = NULL; g_nmsg = 0;
}
/* the scene of a context (made when it is first seen) */
static struct scene *scene_for(uint32_t ctx, int *idx)
{
	for (int i = 0; i < nscenes; i++) if (scenes[i]->ctx == ctx) { *idx = i; return scenes[i]; }
	if (nscenes >= MAXSCENES) return NULL;
	struct scene *n = calloc(1, sizeof *n);
	if (!n) return NULL;
	n->ctx = ctx; scenes[nscenes] = n; *idx = nscenes++;
	return n;
}
/* one commit message; returns the index of the scene it belongs to (the context is the second word of its body), -1 when it was not understood */
int ca_feed_key(uint32_t key, const uint8_t *m, size_t n)
{
	int idx = -1;
	if (n < 0x24) return -1;
	if ((S = scene_for(key, &idx)) == NULL) return -1;
	message(m, n, &g_nmsg);
	return idx;
}
int ca_feed(const uint8_t *m, size_t n)
{
	size_t st = 0x1c; uint32_t bits, ctx = 0;
	if (n < 0x24) return -1;
	memcpy(&bits, m, 4);
	if (bits & 0x80000000u) { uint32_t nd; memcpy(&nd, m + 0x18, 4); for (uint32_t i = 0; i < nd && st + 12 <= n; i++) st += m[st + 11] == 1 ? 16 : 12; }
	if (st + 8 > n) return -1;
	memcpy(&ctx, m + st + 4, 4);
	return ca_feed_key(ctx, m, n);
}
int ca_load_file(const char *path)
{
	FILE *f = fopen(path, "rb");
	if (!f) return -1;
	fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
	uint8_t *d = malloc(sz + 1);
	if (!d || fread(d, 1, sz, f) != (size_t)sz) { fclose(f); free(d); return -1; }
	fclose(f);
	ca_reset();
	for (long p = 0; p + 4 <= sz;) {
		uint32_t n; memcpy(&n, d + p, 4); p += 4;
		if (p + n > (unsigned long)sz) break;
		ca_feed(d + p, n);
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
typedef struct { uint8_t *px; int w, h, stride; } ca_canvas;
static void blend(ca_canvas *win, int x, int y, int r, int g, int b, int a)
{
	if (x < 0 || y < 0 || x >= win->w || y >= win->h || a <= 0) return;
	uint8_t *p = win->px + (size_t)y * win->stride + x * 4;
	if (a > 255) a = 255;
	p[0] = (uint8_t)((p[0] * (255 - a) + b * a) / 255); p[1] = (uint8_t)((p[1] * (255 - a) + g * a) / 255); p[2] = (uint8_t)((p[2] * (255 - a) + r * a) / 255); p[3] = (uint8_t)(a + p[3] * (255 - a) / 255);
}
static void paint_layer(ca_canvas *win, uint64_t id, double ox, double oy, double op, int depth)
{
	layer_t *l = find(id);
	int H = win->h;
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
static void paint_scene(ca_canvas *win)
{
	uint64_t roots[MAXL]; int nr = 0;
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
int ca_scene_nroots(int scene) { return scene >= 0 && scene < nscenes ? scenes[scene]->nroots : 0; }
uint32_t ca_scene_root_ctx(int scene, int i) { return scene >= 0 && scene < nscenes && i >= 0 && i < scenes[scene]->nroots ? scenes[scene]->rootctx[i] : 0; }
/* the tree of one context (its root layer) on a transparent canvas: the content of the window of that context */
void ca_paint_root(int scene, int i, uint8_t *bgra, int w_, int h_, int stride)
{
	ca_canvas cv = { bgra, w_, h_, stride };
	for (int j = 0; j < h_; j++) memset(bgra + (size_t)j * stride, 0, (size_t)w_ * 4);
	if (scene < 0 || scene >= nscenes || i < 0 || i >= scenes[scene]->nroots) return;
	S = scenes[scene];
	paint_layer(&cv, S->rootid[i], 0, 0, 1.0, 0);
}
/* every scene over a dark background (opaque): for a viewer that shows the whole stream in one picture */
void ca_paint(uint8_t *bgra, int w_, int h_, int stride)
{
	ca_canvas cv = { bgra, w_, h_, stride };
	for (int j = 0; j < h_; j++) for (int i = 0; i < w_; i++) { uint8_t *p = bgra + (size_t)j * stride + i * 4; p[0] = 30; p[1] = 28; p[2] = 28; p[3] = 255; }
	for (int k = 0; k < nscenes; k++) { S = scenes[k]; paint_scene(&cv); }
}
/* one scene on a transparent canvas (premultiplied BGRA): the content of a window of wsd */
void ca_paint_scene(int idx, uint8_t *bgra, int w_, int h_, int stride)
{
	ca_canvas cv = { bgra, w_, h_, stride };
	for (int j = 0; j < h_; j++) memset(bgra + (size_t)j * stride, 0, (size_t)w_ * 4);
	if (idx < 0 || idx >= nscenes) return;
	S = scenes[idx]; paint_scene(&cv);
}
