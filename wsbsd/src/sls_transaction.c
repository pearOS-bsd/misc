/* Transactions: TransactionCommitAsync / CommitSync (30429 / 30430). A transaction is a byte stream of operations; the decoder follows PKGTransactionCommit.
 * Stream: opcode byte (1..0x8c, 0xff ends), then the operation's arguments. Argument encodings (from _SLSTransactionDecode_packed64 and the PKGTransaction* decoders):
 *   packed64: tag byte t; t < 0x10: value = -(t & 1) (0 or -1); else n = t >> 4 big-endian bytes follow, sign-extended when t & 1
 *   float: byte 'H' (0x48) + 4 raw bytes, otherwise a packed64 integer converted to float; double: byte 0x88 + 8 raw bytes, otherwise a packed64 integer
 *   region: packed64 length, then that many raw bytes (a serialized region)
 * Opcode numbers are those of the macOS 27.0 SkyLight (the table PKGTransactionOpcodeInfos); other releases number them differently.
 * Message: complex, OOL descriptor (count@0x18 = 1, type@0x27, size@0x28), NDR@0x2c, flags@0x34, id64@0x38, inline length@0x40 (<= 0x4000), inline bytes@0x44,
 * repeated OOL size after the padded inline bytes; size = pad4(inline) + 0x48. Exactly one of inline / OOL carries the stream, else 1001. */
#include "wsd_priv.h"
#include "ws_region.h"
#include <stdlib.h>
#include <string.h>

enum {
	OP_ORDER_WINDOW = 1, OP_SET_ALPHA = 3, OP_SET_LEVEL = 6, OP_SET_OPAQUE_SHAPE = 7, OP_SET_RESOLUTION = 10, OP_SET_SHAPE = 11, OP_SET_SUBLEVEL = 12, OP_MOVE_WITH_GROUP = 22, OP_BIND_SURFACE = 51, OP_ORDER_SURFACE = 52, OP_SET_SURFACE_BOUNDS = 53, OP_SET_SURFACE_OPACITY = 54, OP_REMOVE_SURFACE = 95, OP_SET_CORNER_RADIUS = 105, OP_SET_TAGS = 118, OP_CONTENT_BLUR = 134,
};

typedef struct { const uint8_t *p; size_t n; int bad; } rd_t;

static uint64_t get_packed(rd_t *r)
{
	if (!r->n) { r->bad = 1; return 0; }
	uint8_t t = *r->p++; r->n--;
	uint64_t v = (uint64_t)0 - (uint64_t)(t & 1);
	if (t < 0x10) return v;
	size_t k = t >> 4;
	if (k > r->n || k > 8) { r->bad = 1; return 0; }
	while (k--) { v = (uint64_t)*r->p++ | (v << 8); r->n--; }
	return v;
}
static double get_double(rd_t *r)
{
	if (!r->n) { r->bad = 1; return 0; }
	if (*r->p == 0x88) { if (r->n < 9) { r->bad = 1; return 0; } double d; memcpy(&d, r->p + 1, 8); r->p += 9; r->n -= 9; return d; }
	return (double)(int64_t)get_packed(r);
}
static float get_float(rd_t *r)
{
	if (!r->n) { r->bad = 1; return 0; }
	if (*r->p == 'H') { if (r->n < 5) { r->bad = 1; return 0; } float f; memcpy(&f, r->p + 1, 4); r->p += 5; r->n -= 5; return f; }
	return (float)(int64_t)get_packed(r);
}
static int get_byte(rd_t *r) { if (!r->n) { r->bad = 1; return 0; } r->n--; return *r->p++; }

/* applies the operations; returns 0, or 1001 for a stream it cannot decode */
static int run_stream(conn *c, const uint8_t *p, size_t n)
{
	rd_t r = { p, n, 0 };
	while (r.n) {
		int op = get_byte(&r);
		if (op == 0xff) return 0;
		if (op < 1 || op > 0x8c) return 1001;                                    /* "invalid transaction opcode" */
		switch (op) {
		case OP_ORDER_WINDOW: {
			uint32_t wid = (uint32_t)get_packed(&r); int mode = (int8_t)get_byte(&r); uint32_t rel = (uint32_t)get_packed(&r);
			if (r.bad) return 1001;
			if (holds_rights(c, wid)) ws_order_window(srv, wid, mode, rel);
			break;
		}
		case OP_SET_ALPHA: {
			uint32_t wid = (uint32_t)get_packed(&r); float a = get_float(&r); (void)get_float(&r);
			if (r.bad) return 1001;
			if (holds_rights(c, wid)) ws_set_window_alpha(srv, wid, a);
			break;
		}
		case OP_SET_LEVEL: {
			uint32_t wid = (uint32_t)get_packed(&r); int lv = (int)get_packed(&r);
			if (r.bad) return 1001;
			if (holds_rights(c, wid)) ws_set_window_level(srv, wid, lv);
			break;
		}
		case OP_SET_SUBLEVEL: {
			uint32_t wid = (uint32_t)get_packed(&r); int sub = (int)(int16_t)get_packed(&r);
			if (r.bad) return 1001;
			if (holds_rights(c, wid)) ws_set_window_sublevel(srv, wid, sub);
			break;
		}
		case OP_MOVE_WITH_GROUP: {
			uint32_t wid = (uint32_t)get_packed(&r); double x = get_double(&r), y = get_double(&r);
			if (r.bad) return 1001;
			if (holds_rights(c, wid)) ws_move_window(srv, wid, (int)x, (int)y);
			break;
		}
		case OP_SET_SHAPE: {
			uint32_t wid = (uint32_t)get_packed(&r); uint64_t len = get_packed(&r);
			if (r.bad || len > r.n) return 1001;
			if (holds_rights(c, wid) && len) {
				ws_rect *rc = NULL; int nr = 0; ws_rect bb;
				if (ws_region_parse(r.p, (uint32_t)len, &rc, &nr, &bb) == 0 && bb.w > 0 && bb.h > 0) ws_resize_window(srv, wid, bb.x + bb.w, bb.y + bb.h);
				free(rc);
			}
			r.p += len; r.n -= len;
			break;
		}
		case OP_SET_TAGS: {
			uint32_t wid = (uint32_t)get_packed(&r); uint64_t lo = get_packed(&r) & 0xffffffffu, hi = get_packed(&r); int clear = get_byte(&r) & 1;
			if (r.bad) return 1001;
			if (holds_rights(c, wid)) ws_window_set_tags(srv, wid, lo | (hi << 32), clear);
			break;
		}
		case OP_SET_OPAQUE_SHAPE: {                                                  /* wid, region length, region bytes */
			uint32_t wid = (uint32_t)get_packed(&r); uint64_t len = get_packed(&r);
			if (r.bad || len > r.n) return 1001;
			(void)wid; r.p += len; r.n -= len;                                       /* accepted, not used for composition yet */
			break;
		}
		case OP_SET_RESOLUTION: { uint32_t wid = (uint32_t)get_packed(&r); double res = get_double(&r); if (r.bad) return 1001; (void)wid; (void)res; break; }
		case OP_SET_CORNER_RADIUS: {
			uint32_t wid = (uint32_t)get_packed(&r); double rad = get_double(&r);
			if (r.bad) return 1001;
			if (holds_rights(c, wid)) ws_set_window_corner_radius(srv, wid, (int)rad);
			break;
		}
		case OP_BIND_SURFACE: {                                                       /* wid, surface id, kind, a, b: the BindSurface request */
			uint32_t wid = (uint32_t)get_packed(&r), sid = (uint32_t)get_packed(&r); int kind = (int)get_packed(&r); uint32_t a = (uint32_t)get_packed(&r), b = (uint32_t)get_packed(&r);
			if (r.bad) return 1001;
			(void)wsd_bind_surface(c, wid, sid, kind, a, b);
			break;
		}
		case OP_REMOVE_SURFACE: { uint32_t wid = (uint32_t)get_packed(&r), sid = (uint32_t)get_packed(&r); if (r.bad) return 1001; (void)wsd_remove_surface(c, wid, sid); break; }
		case OP_ORDER_SURFACE: { uint32_t wid = (uint32_t)get_packed(&r), sid = (uint32_t)get_packed(&r); (void)get_byte(&r); (void)get_packed(&r); if (r.bad) return 1001; (void)wid; (void)sid; break; }
		case OP_SET_SURFACE_BOUNDS: { (void)get_packed(&r); (void)get_packed(&r); (void)get_double(&r); (void)get_double(&r); (void)get_double(&r); (void)get_double(&r); if (r.bad) return 1001; break; }
		case OP_SET_SURFACE_OPACITY: { (void)get_packed(&r); (void)get_packed(&r); (void)get_byte(&r); if (r.bad) return 1001; break; }
		case OP_CONTENT_BLUR: {
			uint32_t wid = (uint32_t)get_packed(&r); (void)get_float(&r);
			if (r.bad) return 1001;
			(void)wid;                                                              /* content blur: accepted, drawn by the layer tree later */
			break;
		}
		default: return 1001;                                                        /* a valid opcode this server does not decode yet */
		}
	}
	return 0;
}

int sls_transaction_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (h->msgh_id != SLS_MSG_TransactionCommitAsync && h->msgh_id != SLS_MSG_TransactionCommitSync) return -2;
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size < 0x48 || h->msgh_size > 0x4048 || len < h->msgh_size || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
	if (buf[0x27] != 1) return reply_simple(c->fd, h, -300);
	uint32_t osz = rd32(buf, 0x28), il = rd32(buf, 0x40), P = (il + 3) & ~3u;
	if (il > 0x4000 || h->msgh_size != P + 0x48 || len != (size_t)h->msgh_size + osz) return reply_simple(c->fd, h, -304);
	if (rd32(buf, 0x44 + P) != osz) return reply_simple(c->fd, h, -300);
	if ((il != 0) == (osz != 0)) return reply_simple(c->fd, h, 1001);              /* exactly one of inline / out-of-line */
	int rc = il ? run_stream(c, buf + 0x44, il) : run_stream(c, buf + h->msgh_size, osz);
	wsd_dirty = 1;
	return reply_simple(c->fd, h, rc);
}
