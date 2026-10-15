/* A small writer for binary property lists (bplist00): arrays, dictionaries, ASCII strings and non-negative integers. Objects are numbered depth first, a dictionary's keys before
 * its values, and identical strings / integers share one object: the layout the real server's serializer produced for the managed display list (recorded on a macOS runner). */
#include "wsd_priv.h"
#include "bplist.h"
#include <stdlib.h>
#include <string.h>

#define BP_MAXOBJ 256
typedef struct { uint8_t *b; size_t n, cap; const bp_node *rep[BP_MAXOBJ]; int nobj; } bp_w;

static void put(bp_w *w, const void *d, size_t n) { if (w->n + n > w->cap) { w->cap = (w->n + n) * 2 + 64; w->b = realloc(w->b, w->cap); } memcpy(w->b + w->n, d, n); w->n += n; }
static void u8(bp_w *w, uint8_t v) { put(w, &v, 1); }
static void be(bp_w *w, uint64_t v, int nb) { for (int i = nb - 1; i >= 0; i--) u8(w, (uint8_t)(v >> (8 * i))); }
static void marker(bp_w *w, uint8_t type, size_t len)
{
	if (len < 15) { u8(w, (uint8_t)(type | len)); return; }
	u8(w, (uint8_t)(type | 0xf));
	int nb = len < 256 ? 1 : 2;
	u8(w, (uint8_t)(0x10 | (nb == 1 ? 0 : 1))); be(w, len, nb);
}

static int assign(bp_w *w, bp_node *x)
{
	if (w->nobj >= BP_MAXOBJ - 1) return -1;
	if (x->kind == BP_INT || x->kind == BP_STR || x->kind == BP_REAL)
		for (int i = 0; i < w->nobj; i++) {
			const bp_node *r = w->rep[i];
			if (r->kind == x->kind && ((x->kind == BP_INT && r->i == x->i) || (x->kind == BP_STR && !strcmp(r->s, x->s)) || (x->kind == BP_REAL && r->d == x->d))) { x->id = i; return i; }
		}
	x->id = w->nobj; w->rep[w->nobj++] = x;
	if (x->kind == BP_ARRAY) for (int k = 0; k < x->n; k++) assign(w, x->kids[k]);
	if (x->kind == BP_DICT) { for (int k = 0; k < x->n; k++) assign(w, x->keys[k]); for (int k = 0; k < x->n; k++) assign(w, x->kids[k]); }
	return x->id;
}

size_t bp_serialize(bp_node *root, uint8_t **out)
{
	bp_w w; memset(&w, 0, sizeof w);
	put(&w, "bplist00", 8);
	assign(&w, root);
	size_t off[BP_MAXOBJ];
	for (int i = 0; i < w.nobj; i++) {
		const bp_node *x = w.rep[i]; off[i] = w.n;
		switch (x->kind) {
		case BP_INT: if (x->i < 256) { u8(&w, 0x10); u8(&w, (uint8_t)x->i); } else if (x->i < 65536) { u8(&w, 0x11); be(&w, x->i, 2); } else { u8(&w, 0x12); be(&w, x->i, 4); } break;
		case BP_REAL: { uint64_t bits; memcpy(&bits, &x->d, 8); u8(&w, 0x23); be(&w, bits, 8); break; }
		case BP_STR: marker(&w, 0x50, strlen(x->s)); put(&w, x->s, strlen(x->s)); break;
		case BP_ARRAY: marker(&w, 0xa0, (size_t)x->n); for (int k = 0; k < x->n; k++) u8(&w, (uint8_t)x->kids[k]->id); break;
		case BP_DICT: marker(&w, 0xd0, (size_t)x->n); for (int k = 0; k < x->n; k++) u8(&w, (uint8_t)x->keys[k]->id); for (int k = 0; k < x->n; k++) u8(&w, (uint8_t)x->kids[k]->id); break;
		}
	}
	size_t table = w.n;
	for (int i = 0; i < w.nobj; i++) u8(&w, (uint8_t)off[i]);           /* offsets fit in a byte for the small lists built here; larger ones use two */
	uint8_t tr[32]; memset(tr, 0, sizeof tr);
	tr[6] = 1; tr[7] = 1;                                               /* offset size, reference size */
	tr[15] = (uint8_t)w.nobj; tr[23] = 0;                               /* object count, top object */
	for (int i = 0; i < 8; i++) tr[24 + i] = (uint8_t)(table >> (8 * (7 - i)));
	put(&w, tr, 32);
	*out = w.b;
	return w.n;
}

/* the text of a property list holding one string (bplist00, ASCII or UTF-16 string as the first object); 0 when it is anything else */
int bp_string(const uint8_t *b, size_t n, char *out, size_t cap)
{
	if (n < 10 || memcmp(b, "bplist00", 8)) return 0;
	uint8_t m = b[8]; size_t len = m & 0xf, off = 9;
	if ((m & 0xf0) != 0x50 && (m & 0xf0) != 0x60) return 0;
	if (len == 0xf) { if (off >= n || (b[off] & 0xf0) != 0x10) return 0; int nb = 1 << (b[off] & 0xf); off++; len = 0; for (int i = 0; i < nb && off < n; i++) len = (len << 8) | b[off++]; }
	if (len + 1 > cap) return 0;
	if ((m & 0xf0) == 0x50) { if (off + len > n) return 0; memcpy(out, b + off, len); out[len] = 0; return 1; }
	if (off + 2 * len > n) return 0;
	for (size_t i = 0; i < len; i++) out[i] = (char)b[off + 2 * i + 1];                 /* UTF-16BE, the low byte */
	out[len] = 0;
	return 1;
}


/* ---- reading: just enough of the format to take keys out of a stored dictionary and to read an array of strings ---- */
typedef struct { const uint8_t *b; size_t n, tbl; int osz, rsz; uint64_t nobj, top; } bp_r;
static uint64_t rdn(const uint8_t *p, int nb) { uint64_t v = 0; for (int i = 0; i < nb; i++) v = (v << 8) | p[i]; return v; }
static int bp_open(bp_r *r, const uint8_t *b, size_t n)
{
	if (n < 8 + 32 || memcmp(b, "bplist00", 8)) return 0;
	const uint8_t *t = b + n - 32;
	r->b = b; r->n = n; r->osz = t[6]; r->rsz = t[7]; r->nobj = rdn(t + 8, 8); r->top = rdn(t + 16, 8); r->tbl = (size_t)rdn(t + 24, 8);
	if (r->osz < 1 || r->osz > 8 || r->rsz < 1 || r->rsz > 8 || r->nobj == 0 || r->top >= r->nobj || r->tbl > n - 32 || r->nobj > 100000 || (n - 32 - r->tbl) / (size_t)r->osz < r->nobj) return 0;
	return 1;
}
static int bp_obj(const bp_r *r, uint64_t i, size_t *off) { if (i >= r->nobj) return 0; *off = (size_t)rdn(r->b + r->tbl + i * (uint64_t)r->osz, r->osz); return *off < r->tbl; }
/* marker at off: type nibble, element count, offset of the payload */
static int bp_head(const bp_r *r, size_t off, int *type, size_t *len, size_t *data)
{
	uint8_t m = r->b[off]; *type = m >> 4; *len = m & 0xf; *data = off + 1;
	if (*len == 0xf && *type != 0 ) {
		if (*data >= r->tbl || (r->b[*data] & 0xf0) != 0x10) return 0;
		int nb = 1 << (r->b[*data] & 0xf); if (nb > 8 || *data + 1 + (size_t)nb > r->tbl) return 0;
		*len = (size_t)rdn(r->b + *data + 1, nb); *data += 1 + (size_t)nb;
	}
	return 1;
}
static int bp_strobj(const bp_r *r, uint64_t i, char *out, size_t cap)
{
	size_t off, len, data; int type;
	if (!bp_obj(r, i, &off) || !bp_head(r, off, &type, &len, &data) || (type != 5 && type != 6)) return 0;
	size_t bytes = type == 5 ? len : 2 * len;
	if (len + 1 > cap || data + bytes > r->tbl) return 0;
	if (type == 5) memcpy(out, r->b + data, len); else for (size_t k = 0; k < len; k++) out[k] = (char)r->b[data + 2 * k + 1];
	out[len] = 0; return 1;
}

/* the strings of a property list whose top object is an array of strings; returns the count (<= max) or -1 */
int bp_string_array(const uint8_t *b, size_t n, char out[][64], int max)
{
	bp_r r; size_t off, len, data; int type;
	if (!bp_open(&r, b, n) || !bp_obj(&r, r.top, &off) || !bp_head(&r, off, &type, &len, &data) || type != 0xa) return -1;
	if (len > (size_t)max || data + len * (size_t)r.rsz > r.tbl) return -1;
	for (size_t k = 0; k < len; k++) if (!bp_strobj(&r, rdn(b + data + k * (size_t)r.rsz, r.rsz), out[k], 64)) return -1;
	return (int)len;
}

/* a copy of the dictionary property list without the entries whose key is one of keys[0..nk): the new top dictionary is appended as one more object, the old objects stay (unreferenced).
 * Returns the new length, or 0 when the list is not a dictionary or cannot take one more object. */
size_t bp_dict_remove(const uint8_t *b, size_t n, char keys[][64], int nk, uint8_t **out)
{
	bp_r r; size_t off, len, data; int type;
	if (!bp_open(&r, b, n) || !bp_obj(&r, r.top, &off) || !bp_head(&r, off, &type, &len, &data) || type != 0xd) return 0;
	if (data + 2 * len * (size_t)r.rsz > r.tbl) return 0;
	if (r.rsz < 8 && r.nobj + 1 > ((uint64_t)1 << (8 * r.rsz))) return 0;
	uint64_t *kr = malloc((len + 1) * sizeof *kr * 2); if (!kr) return 0;
	size_t kept = 0;
	for (size_t k = 0; k < len; k++) {
		uint64_t kref = rdn(b + data + k * (size_t)r.rsz, r.rsz), vref = rdn(b + data + (len + k) * (size_t)r.rsz, r.rsz); char s[64]; int drop = 0;
		if (bp_strobj(&r, kref, s, sizeof s)) for (int j = 0; j < nk; j++) if (!strcmp(s, keys[j])) drop = 1;
		if (!drop) { kr[kept] = kref; kr[len + kept] = vref; kept++; }
	}
	uint8_t *o = malloc(r.tbl + 32 + 16 + 2 * kept * (size_t)r.rsz + (r.nobj + 1) * (size_t)r.osz + 32);
	if (!o) { free(kr); return 0; }
	memcpy(o, b, r.tbl); size_t w = r.tbl, newoff = w;
	if (kept < 15) o[w++] = (uint8_t)(0xd0 | kept); else { o[w++] = 0xdf; o[w++] = 0x13; for (int i = 3; i >= 0; i--) o[w++] = (uint8_t)(kept >> (8 * i)); }
	for (size_t k = 0; k < kept; k++) for (int i = r.rsz - 1; i >= 0; i--) o[w++] = (uint8_t)(kr[k] >> (8 * i));
	for (size_t k = 0; k < kept; k++) for (int i = r.rsz - 1; i >= 0; i--) o[w++] = (uint8_t)(kr[len + k] >> (8 * i));
	free(kr);
	size_t table = w;
	memcpy(o + w, b + r.tbl, r.nobj * (size_t)r.osz); w += r.nobj * (size_t)r.osz;
	if (r.osz < 8 && newoff >= ((size_t)1 << (8 * r.osz))) { free(o); return 0; }
	for (int i = r.osz - 1; i >= 0; i--) o[w++] = (uint8_t)(newoff >> (8 * i));
	uint8_t tr[32]; memcpy(tr, b + n - 32, 32);
	uint64_t nn = r.nobj + 1, top = r.nobj;
	for (int i = 0; i < 8; i++) { tr[8 + i] = (uint8_t)(nn >> (8 * (7 - i))); tr[16 + i] = (uint8_t)(top >> (8 * (7 - i))); tr[24 + i] = (uint8_t)((uint64_t)table >> (8 * (7 - i))); }
	memcpy(o + w, tr, 32); w += 32;
	*out = o; return w;
}
