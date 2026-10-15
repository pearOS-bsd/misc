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
	if (x->kind == BP_INT || x->kind == BP_STR)
		for (int i = 0; i < w->nobj; i++) {
			const bp_node *r = w->rep[i];
			if (r->kind == x->kind && ((x->kind == BP_INT && r->i == x->i) || (x->kind == BP_STR && !strcmp(r->s, x->s)))) { x->id = i; return i; }
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
