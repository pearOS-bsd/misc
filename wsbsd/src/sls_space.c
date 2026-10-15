/* Spaces: a table of spaces (the default user space has id 1), their names and values, the windows assigned to them, and show / hide state. Layouts from the decompiled routines.
 * Not modelled: the managed displays a space is bound to, owners, shapes and tiles. */
#include "wsd_priv.h"
#include <stdlib.h>
#include <string.h>

#define MAXSP 64
#define MAXMEM 512
static struct { int used; uint64_t id; uint32_t type; char name[130]; uint8_t *values; uint32_t vlen; float alpha; int shown; } sp[MAXSP];
static struct { int used; uint32_t wid; uint64_t sid; } mem[MAXMEM];
static uint64_t next_space = 2;
static int sp_ready;

static void sp_init(void)
{
	if (sp_ready) return;
	sp_ready = 1;
	sp[0].used = 1; sp[0].id = 1; sp[0].type = 0; sp[0].alpha = 1.0f; sp[0].shown = 1;       /* the default user space */
}
static int sp_find(uint64_t id) { sp_init(); for (int i = 0; i < MAXSP; i++) if (sp[i].used && sp[i].id == id) return i; return -1; }

uint64_t sls_space_of_window(uint32_t wid)
{
	for (int i = 0; i < MAXMEM; i++) if (mem[i].used && mem[i].wid == wid && sp_find(mem[i].sid) >= 0) return mem[i].sid;
	return 1;
}

/* the text of a property list holding one string (bplist00, ASCII or UTF-16 string as the first object); 0 when it is anything else */
static int bplist_string(const uint8_t *b, size_t n, char *out, size_t cap)
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

static int reply_u64(conn *c, const mach_msg_header_t *h, uint64_t v)
{
	uint8_t r[0x2c]; memset(r, 0, sizeof r);
	fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
	memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
	memcpy(r + 0x24, &v, 8);
	return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
}

int sls_space_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	int err, osz;
	switch (h->msgh_id) {
	case SLS_MSG_SpaceCreate: {                                                    /* OOL plist (options), type@0x34, size repeated@0x38; size 0x3c. Reply 0x2c: retcode, the new space id (u64) at 0x24 */
		sp_init();
		osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		for (int i = 0; i < MAXSP; i++) if (!sp[i].used) {
			memset(&sp[i], 0, sizeof sp[i]);
			sp[i].used = 1; sp[i].id = next_space++; sp[i].type = rd32(buf, 0x34); sp[i].alpha = 1.0f;
			return reply_u64(c, h, sp[i].id);
		}
		return reply_simple(c->fd, h, 1000);
	}
	case SLS_MSG_SpaceDestroy: {                                                   /* id u64@0x20, size 0x28; 1001 for an unknown space (and the default one) */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = sp_find(id);
		if (i < 0 || id == 1) return reply_simple(c->fd, h, 0x3e9);
		free(sp[i].values); memset(&sp[i], 0, sizeof sp[i]);
		for (int k = 0; k < MAXMEM; k++) if (mem[k].used && mem[k].sid == id) mem[k].used = 0;
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SpaceSetName: {                                                   /* id u64@0x20, name length@0x2c (<= 0x400), name@0x30; size pad4(n) + 0x30 */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x30 || h->msgh_size > 0x430) return reply_simple(c->fd, h, -304);
		uint32_t n = rd32(buf, 0x2c);
		if (n > 0x400 || h->msgh_size != ((n + 3) & ~3u) + 0x30) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = sp_find(id);
		if (i >= 0) { size_t k = n < sizeof sp[i].name - 1 ? n : sizeof sp[i].name - 1; memcpy(sp[i].name, buf + 0x30, k); sp[i].name[k] = 0; sp[i].name[strnlen(sp[i].name, k)] = 0; }
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SpaceWithName: {                                                  /* OOL plist holding the name; size repeated@0x34; size 0x38. Reply 0x2c: the space id (0: none) */
		osz = ool_request(h, buf, len, 0x38, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x34)) return reply_simple(c->fd, h, -300);
		char name[130];
		if (osz == 0 || !bplist_string(buf + 0x38, (uint32_t)osz, name, sizeof name)) return reply_simple(c->fd, h, 1000);
		sp_init();
		uint64_t found = 0;
		for (int i = 0; i < MAXSP; i++) if (sp[i].used && sp[i].name[0] && !strcmp(sp[i].name, name)) { found = sp[i].id; break; }
		return reply_u64(c, h, found);
	}
	case SLS_MSG_SpaceSetValues: {                                                 /* OOL plist (values to merge); space id u64@0x34, size repeated@0x3c; size 0x40: the latest values are kept as they came (no merge) */
		osz = ool_request(h, buf, len, 0x40, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x3c)) return reply_simple(c->fd, h, -300);
		uint64_t id; memcpy(&id, buf + 0x34, 8);
		int i = sp_find(id);
		if (i >= 0) { free(sp[i].values); sp[i].values = osz ? malloc((size_t)osz) : NULL; if (sp[i].values) { memcpy(sp[i].values, buf + 0x40, (size_t)osz); sp[i].vlen = (uint32_t)osz; } else sp[i].vlen = 0; }
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SpaceGetAlpha: {                                                  /* id u64@0x20, size 0x28; reply value: the alpha as a float; 1010 for an unknown space */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = sp_find(id);
		if (i < 0) return reply_simple(c->fd, h, 0x3f2);
		uint32_t bits; memcpy(&bits, &sp[i].alpha, 4);
		return reply_value(c->fd, h, (int32_t)bits);
	}
	case SLS_MSG_ShowSpaces:
	case SLS_MSG_HideSpaces: {                                                     /* OOL array of space ids (u64); count@0x34; size 0x38; always 0 */
		osz = ool_request(h, buf, len, 0x38, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz / 8 != rd32(buf, 0x34)) return reply_simple(c->fd, h, -300);
		for (int k = 0; k < osz / 8; k++) { uint64_t id; memcpy(&id, buf + 0x38 + 8 * k, 8); int i = sp_find(id); if (i >= 0) sp[i].shown = h->msgh_id == SLS_MSG_ShowSpaces; }
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_AddWindowsToSpaces:
	case SLS_MSG_RemoveWindowsFromSpaces: {                                        /* two OOL arrays: window ids (u32) and space ids (u64); counts@0x44 and @0x48; size 0x4c; always 0 */
		sp_init();
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x4c || len < 0x4c || rd32(buf, 0x18) != 2) return reply_simple(c->fd, h, -304);
		uint32_t s1 = rd32(buf, 0x28), s2 = rd32(buf, 0x38);
		if (buf[0x27] != 1 || buf[0x37] != 1 || rd32(buf, 0x44) != s1 / 4 || rd32(buf, 0x48) != s2 / 8) return reply_simple(c->fd, h, -300);
		if (len != 0x4c + (size_t)s1 + s2) return reply_simple(c->fd, h, -304);
		const uint8_t *wins = buf + 0x4c, *spc = buf + 0x4c + s1;
		for (uint32_t a = 0; a < s1 / 4; a++) for (uint32_t b = 0; b < s2 / 8; b++) {
			uint32_t wid = rd32(wins, 4 * a); uint64_t sid; memcpy(&sid, spc + 8 * b, 8);
			if (!ws_window_exists(srv, wid) || sp_find(sid) < 0) continue;
			int hit = -1; for (int k = 0; k < MAXMEM; k++) if (mem[k].used && mem[k].wid == wid && mem[k].sid == sid) hit = k;
			if (h->msgh_id == SLS_MSG_AddWindowsToSpaces) { if (hit < 0) for (int k = 0; k < MAXMEM; k++) if (!mem[k].used) { mem[k].used = 1; mem[k].wid = wid; mem[k].sid = sid; break; } }
			else if (hit >= 0) mem[hit].used = 0;
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_ProcessAssignToSpace:                                             /* pid@0x20, space id u64@0x24, size 0x2c: kept nowhere (windows carry their own space) */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0);
	}
	return -2;
}

void sls_space_owner_cleanup(uint32_t owner) { (void)owner; for (int k = 0; k < MAXMEM; k++) if (mem[k].used && !ws_window_exists(srv, mem[k].wid)) mem[k].used = 0; }
