/* Registered cursor images (decompiled from SkyLight): __XRegisterCursorImages (30293) and __XGetRegisteredCursorImages (30294) with __CGXRegisterCursorImages, _CGXFindCursorRef.
 * A cursor is a name, four floats (the cursor's geometry) and up to 0x40 bitmaps (width, height, BGRA pixels). The registry is kept per connection, or for the whole session when the
 * request says so; a lookup asks the connection first, then the session.
 *
 * Register: complex, one OOL descriptor (the pixels of every bitmap one after the other), size 0x64 .. 0x4e4: OOL size@0x28, name length@0x38 (<= 0x80), the name from 0x3c (a NUL must lie
 * within min(size - 0x3c, 0x80) bytes), padded to 4 (P); then relative to 0x3c + P: session flag byte@+0, "make it the connection cursor" byte@+4, four floats@+8..+0x14, scale@+0x18,
 * a u32@+0x1c, the count of u32 in the bitmap list (<= 0x100, a multiple of 4: width, height, pixel offset, unused per bitmap)@+0x20, the list@+0x24 and the OOL size / 4 after it; size must equal
 * P + count * 4 + 0x64 (-304 otherwise), the trailing size must equal OOL size / 4 (-300). A bitmap that does not fit in the pixels gives 1001. Reply 0x28: 0, cursor id@0x24 (0 unless
 * "connection cursor" was asked for).
 * Get: size 0x2c .. 0xac, name length@0x24 (<= 0x80), name@0x28 padded to 4, then the caller's buffer size (u32): below 4 gives 1001; an unknown name, no bitmap or more than 0x20 (or more
 * than a quarter of the buffer) gives 1007. Reply, complex with one OOL: the pixels of all bitmaps, NDR@0x2c, the four floats@0x34, two u32 (zero)@0x44, the number of u32 in the list@0x4c, the
 * list (width, height, pixel offset, pixel count)@0x50 and the pixel byte count after it; size 0x54 + 16 * bitmaps. */
#include "wsd_priv.h"
#include <stdlib.h>
#include <string.h>

#define MAX_CURSORS 128
#define MAX_BITMAPS 0x40
typedef struct { int w, h; uint8_t *px; } cbmp;
typedef struct { int used; uint32_t owner; int session; char name[0x81]; float f[4]; int n; cbmp b[MAX_BITMAPS]; } cursor_rec;
static cursor_rec reg[MAX_CURSORS];
static uint32_t next_cursor_id = 1;

static void free_rec(cursor_rec *r) { for (int i = 0; i < r->n; i++) free(r->b[i].px); memset(r, 0, sizeof *r); }
static cursor_rec *find_rec(uint32_t owner, const char *name)
{
	for (int pass = 0; pass < 2; pass++)                                         /* the connection's own, then the session's */
		for (int i = 0; i < MAX_CURSORS; i++)
			if (reg[i].used && !strcmp(reg[i].name, name) && (pass ? reg[i].session : (!reg[i].session && reg[i].owner == owner))) return &reg[i];
	return NULL;
}
void sls_cursor_owner_cleanup(uint32_t owner) { for (int i = 0; i < MAX_CURSORS; i++) if (reg[i].used && !reg[i].session && reg[i].owner == owner) free_rec(&reg[i]); }

static int name_ok(const uint8_t *buf, size_t at, uint32_t size)             /* a NUL within min(size - at, 0x80) bytes from `at` */
{
	size_t n = size - at; if (n > 0x80) n = 0x80;
	return memchr(buf + at, 0, n) != NULL;
}

int sls_cursor_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (h->msgh_id == 30293) {
		uint32_t size = h->msgh_size;
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || rd32(buf, 0x18) != 1 || size < 0x64 || size > 0x4e4 || len < size) return reply_simple(c->fd, h, -304);
		if (buf[0x27] != 1) return reply_simple(c->fd, h, -300);
		uint32_t osz = rd32(buf, 0x28), nlen = rd32(buf, 0x38);
		if (nlen > 0x80) return reply_simple(c->fd, h, -304);
		uint32_t P = (nlen + 3) & ~3u;
		if (size - 100 < nlen || size < P + 100) return reply_simple(c->fd, h, -304);
		uint32_t cnt = rd32(buf, 0x3c + P + 0x20);
		if (cnt > 0x100 || cnt > (size - P - 100) >> 2 || size - P != cnt * 4 + 100) return reply_simple(c->fd, h, -304);
		if ((osz >> 2) != rd32(buf, 0x3c + P + 0x24 + cnt * 4)) return reply_simple(c->fd, h, -300);
		if (!name_ok(buf, 0x3c, size)) return reply_simple(c->fd, h, -304);
		if (len != (size_t)size + osz) return reply_simple(c->fd, h, -304);
		const uint8_t *b = buf + 0x3c + P, *list = b + 0x24, *pix = buf + size;
		uint32_t scale = rd32(b, 0x18), npx = osz >> 2;
		int nb = (int)(cnt >> 2);
		if (nb > MAX_BITMAPS) nb = MAX_BITMAPS;
		cursor_rec tmp; memset(&tmp, 0, sizeof tmp);
		for (int i = 0; i < nb; i++) {
			int32_t w = (int32_t)rd32(list, 16 * i), hh = (int32_t)rd32(list, 16 * i + 4); uint32_t off = rd32(list, 16 * i + 8);
			if (npx < off || (uint64_t)(npx - off) < (uint64_t)((int64_t)hh * (int64_t)w)) { free_rec(&tmp); return reply_simple(c->fd, h, 1001); }
			if (w <= 0 || hh <= 0) continue;                                    /* an empty bitmap adds nothing */
			tmp.b[tmp.n].px = malloc((size_t)w * hh * 4); if (!tmp.b[tmp.n].px) { free_rec(&tmp); return reply_simple(c->fd, h, 1000); }
			memcpy(tmp.b[tmp.n].px, pix + (size_t)off * 4, (size_t)w * hh * 4); tmp.b[tmp.n].w = w; tmp.b[tmp.n].h = hh; tmp.n++;
		}
		(void)scale;
		for (int i = 0; i < 4; i++) { uint32_t u = rd32(b, 8 + 4 * i); memcpy(&tmp.f[i], &u, 4); }
		uint32_t cid = 0;
		if (b[4]) cid = next_cursor_id++;                                       /* the connection's cursor: its id comes back (the pointer image itself is not switched yet) */
		const char *name = (const char *)buf + 0x3c;
		if (name[0]) {
			cursor_rec *r = find_rec(c->id, name);
			int sess = b[0] != 0;
			if (!r) for (int i = 0; i < MAX_CURSORS; i++) if (!reg[i].used) { r = &reg[i]; break; }
			if (r) {
				if (r->used) free_rec(r);
				*r = tmp; r->used = 1; r->owner = c->id; r->session = sess; strncpy(r->name, name, 0x80); memset(&tmp, 0, sizeof tmp);
			}
		}
		free_rec(&tmp);
		uint8_t rep[0x28]; memset(rep, 0, sizeof rep); fill_reply_header((mach_msg_header_t *)rep, h, sizeof rep, 0); memcpy(rep + 0x18, &WS_NDR, 8);
		memcpy(rep + 0x24, &cid, 4);
		return ws_ipc_send(c->fd, &(struct iovec){ rep, sizeof rep }, 1, NULL, 0);
	}
	if (h->msgh_id == 30294) {
		uint32_t size = h->msgh_size;
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || size < 0x2c || size > 0xac || len != size) return reply_simple(c->fd, h, -304);
		uint32_t nlen = rd32(buf, 0x24), P = (nlen + 3) & ~3u;
		if (nlen > 0x80 || size - 0x2c < nlen || size != P + 0x2c) return reply_simple(c->fd, h, -304);
		if (!name_ok(buf, 0x28, size)) return reply_simple(c->fd, h, -304);
		uint32_t maxb = rd32(buf, 0x28 + P); if (maxb > 0x100) maxb = 0x100;
		if (maxb < 4) return reply_simple(c->fd, h, 1001);
		cursor_rec *r = find_rec(c->id, (const char *)buf + 0x28);
		if (!r || r->n < 1 || r->n > 0x20 || (uint32_t)r->n > (maxb >> 2)) return reply_simple(c->fd, h, 1007);
		size_t total = 0; for (int i = 0; i < r->n; i++) total += (size_t)r->b[i].w * r->b[i].h * 4;
		uint32_t rsz = 0x54 + 16 * (uint32_t)r->n;
		size_t cap = rsz + total + 8;
		uint8_t *m = calloc(1, cap); if (!m) return reply_simple(c->fd, h, 1000);
		fill_reply_header((mach_msg_header_t *)m, h, rsz, 1); memcpy(m + 0x18, &(uint32_t){ 1 }, 4);
		m[0x24] = 1; m[0x25] = 1; m[0x27] = 1;                                    /* deallocate, copy, OOL */
		memcpy(m + 0x28, &(uint32_t){ (uint32_t)total }, 4); memcpy(m + 0x2c, &WS_NDR, 8);
		memcpy(m + 0x34, r->f, 16);
		uint32_t nu = (uint32_t)r->n * 4; memcpy(m + 0x4c, &nu, 4);
		size_t off = 0;
		for (int i = 0; i < r->n; i++) {
			uint32_t d[4] = { (uint32_t)r->b[i].w, (uint32_t)r->b[i].h, (uint32_t)off, (uint32_t)(r->b[i].w * r->b[i].h) };
			memcpy(m + 0x50 + 16 * i, d, 16);
			memcpy(m + rsz + off * 4, r->b[i].px, (size_t)d[3] * 4);
			off += d[3];
		}
		memcpy(m + 0x50 + 16 * r->n, &(uint32_t){ (uint32_t)total }, 4);
		int rc = ws_ipc_send(c->fd, &(struct iovec){ m, rsz + total }, 1, NULL, 0);
		free(m);
		return rc;
	}
	return -2;
}
