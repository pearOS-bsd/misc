#include "ws_evrec.h"
#include <string.h>

static uint32_t rd32(const uint8_t *p) { return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]; }
static void wr32(uint8_t *p, uint32_t v) { p[0] = (uint8_t)(v >> 24); p[1] = (uint8_t)(v >> 16); p[2] = (uint8_t)(v >> 8); p[3] = (uint8_t)v; }

int ws_evrec_parse(const uint8_t *b, size_t len, ws_evrec *out)
{
	memset(out, 0, sizeof *out);
	if (len < 4 || (len & 3) || rd32(b) != 2) return -1;            /* leading word: 2 */
	size_t i = 4;
	while (i < len) {
		if (i + 4 == len && rd32(b + i) == 0x4052) { i = len; break; }                          /* flagsChanged records end with one bare word (0x4052 on the real system) */
		if (i + 8 > len || out->n >= WS_EV_FIELD_MAX) return -1;
		uint32_t tag = rd32(b + i);
		unsigned kind = tag >> 16, top = (tag >> 14) & 3;
		if (kind != 1 && kind != 2) return -1;
		ws_evfield *f = &out->f[out->n];
		f->id = (uint16_t)(tag & 0x3fff); f->kind = (uint8_t)kind;
		i += 4;
		if (top == 1 || (top == 3 && kind == 1)) { f->words = 1; f->v[0] = rd32(b + i); i += 4; }   /* one 32-bit value (integers tagged c0xx too) */
		else if (top == 3 || top == 0) {                              /* a pair of floats, or one 64-bit integer */
			if (i + 8 > len) return -1;
			f->words = 2; f->wide = top == 0; f->v[0] = rd32(b + i); f->v[1] = rd32(b + i + 4); i += 8;
		} else return -1;
		out->n++;
	}
	return 0;
}

const ws_evfield *ws_evrec_find(const ws_evrec *r, unsigned id)
{
	for (int i = 0; i < r->n; i++) if (r->f[i].id == id) return &r->f[i];
	return NULL;
}

static float bits_f(uint32_t v) { float f; memcpy(&f, &v, 4); return f; }

int ws_evrec_type(const ws_evrec *r) { const ws_evfield *f = ws_evrec_find(r, 0x37); return f ? (int)f->v[0] : -1; }
int ws_evrec_location(const ws_evrec *r, float *x, float *y)
{
	const ws_evfield *f = ws_evrec_find(r, 0x38);
	if (!f || f->words != 2) return -1;
	*x = bits_f(f->v[0]); *y = bits_f(f->v[1]);
	return 0;
}
uint32_t ws_evrec_flags(const ws_evrec *r) { const ws_evfield *f = ws_evrec_find(r, 0x3b); return f ? f->v[0] : 0; }
uint64_t ws_evrec_timestamp(const ws_evrec *r) { const ws_evfield *f = ws_evrec_find(r, 0x3a); return f ? ((uint64_t)f->v[0] << 32 | f->v[1]) : 0; }
int ws_evrec_keycode(const ws_evrec *r) { const ws_evfield *f = ws_evrec_find(r, 9); return f ? (int)f->v[0] : -1; }
int ws_evrec_click_state(const ws_evrec *r) { const ws_evfield *f = ws_evrec_find(r, 1); return f ? (int)f->v[0] : 0; }

/* ---- builders ---- */
typedef struct { uint8_t *p; size_t cap, n; int bad; } wbuf;
static void w32(wbuf *w, uint32_t v) { if (w->n + 4 > w->cap) { w->bad = 1; return; } wr32(w->p + w->n, v); w->n += 4; }
static void i32f(wbuf *w, unsigned id, uint32_t v) { w32(w, 0x00014000u | id); w32(w, v); }                    /* integer, 32 bit */
static void i64f(wbuf *w, unsigned id, uint64_t v) { w32(w, 0x00010000u | id); w32(w, (uint32_t)(v >> 32)); w32(w, (uint32_t)v); }
static void f2f(wbuf *w, unsigned id, float x, float y) { uint32_t a, b; memcpy(&a, &x, 4); memcpy(&b, &y, 4); w32(w, 0x0002c000u | id); w32(w, a); w32(w, b); }

/* common head: fields 0x35, 0x36, type, location, second location, timestamp, flags, 0x33, 0x34, second timestamp, 0x6a, 0x6b */
static void head(wbuf *w, int type, float x, float y, uint64_t ts, uint32_t flags)
{
	w32(w, 2);
	i32f(w, 0x35, 0); i32f(w, 0x36, 0); i32f(w, 0x37, (uint32_t)type);
	f2f(w, 0x38, x, y); f2f(w, 0x39, 0, 0);
	i64f(w, 0x3a, ts); i32f(w, 0x3b, flags);
	i32f(w, 0x33, 0); i32f(w, 0x34, 0);
	i64f(w, 0xa9, ts);
	i32f(w, 0x6a, 0); i32f(w, 0x6b, 0);
}

static void tail(wbuf *w)
{
	i32f(w, 0x3c, 0); i64f(w, 0x3d, 0); i64f(w, 0x3e, 0); i32f(w, 0x3f, 0);
}

size_t ws_evrec_make_mouse(uint8_t *out, size_t cap, int type, float x, float y, uint32_t flags, int click_state, int button, uint64_t ts)
{
	wbuf w = { out, cap, 0, 0 };
	int down = type == 1 || type == 3 || type == 25;
	head(&w, type, x, y, ts, flags);
	i32f(&w, 0x07, 0);
	i32f(&w, 0x00, 0);                                              /* mouse event number */
	i32f(&w, 0x01, (uint32_t)click_state);
	i32f(&w, 0x02, down ? 0xffu : 0);                               /* pressure */
	i32f(&w, 0x03, (uint32_t)button);
	i32f(&w, 0x04, 0); i32f(&w, 0x05, 0); i32f(&w, 0x06, 0);
	i32f(&w, 0x59, 0); i32f(&w, 0x5a, 0); i32f(&w, 0x5b, 0); i32f(&w, 0x5c, 0);
	i32f(&w, 0x6c, down ? 1u : 0);
	tail(&w);
	return w.bad ? 0 : w.n;
}

size_t ws_evrec_make_key(uint8_t *out, size_t cap, int down, int keycode, uint32_t flags, float x, float y, uint64_t ts, int ch, int f50)
{
	wbuf w = { out, cap, 0, 0 };
	head(&w, down ? 10 : 11, x, y, ts, flags);
	i32f(&w, 0x09, (uint32_t)keycode); i32f(&w, 0x08, 0); i32f(&w, 0x0a, 0x5c);          /* keycode, autorepeat, keyboard type */
	i32f(&w, 0x4c, 0xfc); i32f(&w, 0x4d, (uint32_t)ch); i32f(&w, 0x4e, (uint32_t)ch);
	i32f(&w, 0x4f, 0); i32f(&w, 0x50, (uint32_t)f50); i32f(&w, 0x51, 0);
	i32f(&w, 0x7f, 0); i32f(&w, 0x80, 0); i32f(&w, 0x52, (uint32_t)ch);
	return w.bad ? 0 : w.n;
}
