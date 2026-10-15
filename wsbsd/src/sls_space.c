/* Spaces: a table of spaces (the default user space has id 1), their names and values, the windows assigned to them, and show / hide state. Layouts from the decompiled routines.
 * Not modelled: the managed displays a space is bound to, owners, shapes and tiles. */
#include "wsd_priv.h"
#include "bplist.h"
#include "ws_region.h"

extern int wsd_screen_w, wsd_screen_h;
#define DISPLAY_UUID "07230EFA-7A8D-4E37-845C-19CC8737EEF5"      /* the display's identifier as the recorded server reports it (a fixed stand-in here) */
static const uint8_t display_uuid_bytes[16] = { 0x07,0x23,0x0e,0xfa,0x7a,0x8d,0x4e,0x37,0x84,0x5c,0x19,0xcc,0x87,0x37,0xee,0xf5 };
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
		if (osz == 0 || !bp_string(buf + 0x38, (uint32_t)osz, name, sizeof name)) return reply_simple(c->fd, h, 1000);
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
	case SLS_MSG_SpaceGetType: {                                                   /* id u64@0x20, size 0x28; reply value: the space type; 1010 for an unknown space */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = sp_find(id);
		if (i < 0) return reply_simple(c->fd, h, 0x3f2);
		return reply_value(c->fd, h, (int32_t)sp[i].type);
	}
	case SLS_MSG_SpaceCopyName: {                                                  /* id u64@0x20, size 0x28; reply pad4(len + 1) + 0x2c: 0@0x24, length + 1@0x28, the name from 0x2c (the default space has the empty name, recorded); 1010 for an unknown space */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = sp_find(id);
		if (i < 0) return reply_simple(c->fd, h, 0x3f2);
		uint32_t n = (uint32_t)strlen(sp[i].name) + 1, size = ((n + 3) & ~3u) + 0x2c;
		uint8_t *r = calloc(1, size); if (!r) return reply_simple(c->fd, h, 1000);
		fill_reply_header((mach_msg_header_t *)r, h, size, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR); wr32(r, 0x28, n); memcpy(r + 0x2c, sp[i].name, n);
		int rc = ws_ipc_send(c->fd, &(struct iovec){ r, size }, 1, NULL, 0);
		free(r);
		return rc;
	}
	case SLS_MSG_CopySpaces: {                                                     /* mask@0x20, size 0x24; reply complex 0x38: OOL array of space ids (u64), size = 8 * count@0x34. Bit 2 selects the user spaces, then bit 0 the shown one and bit 1 the hidden ones (7 all, 5 current, 6 others); bits 0 / 1 alone select system spaces, none here (recorded on a macOS runner: masks 1 and 2 give nothing) */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t mask = rd32(buf, 0x20); uint64_t ids[MAXSP]; uint32_t n = 0;
		sp_init();
		for (int i = 0; i < MAXSP; i++) if (sp[i].used && (mask & 4) && ((sp[i].shown && (mask & 1)) || (!sp[i].shown && (mask & 2)))) ids[n++] = sp[i].id;
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, n * 8); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, n);
		struct iovec v[2] = { { m, sizeof m }, { ids, (size_t)n * 8 } };
		return ws_ipc_send(c->fd, v, n ? 2 : 1, NULL, 0);
	}
	case SLS_MSG_CopyManagedDisplaySpaces: {                                       /* size 0x18; reply complex 0x38: OOL bplist, an array with one dictionary per display (Current Space, Spaces, Display Identifier); the layout recorded on a macOS runner (201 bytes for one display with the default space) */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size != 0x18) return reply_simple(c->fd, h, -304);
		sp_init();
		bp_node ints[2 * MAXSP + 4], strs[MAXSP + 8], dicts[2 * MAXSP + 2], arr, top, disp, *kids[3 * MAXSP + 16], *keys[3 * MAXSP + 16];
		static const char *spk[4] = { "id64", "ManagedSpaceID", "type", "uuid" };
		bp_node spkey[4], *spkeyp[4]; for (int k = 0; k < 4; k++) { spkey[k] = (bp_node){ BP_STR, spk[k], 0, 0, NULL, NULL, 0, -1 }; spkeyp[k] = &spkey[k]; }
		int ni = 0, ns = 0, nd = 0, nk = 0, first = -1, nsp = 0;
		bp_node *spaces[MAXSP]; bp_node *cur = NULL;
		bp_node *emptystr = &strs[ns++]; *emptystr = (bp_node){ BP_STR, "", 0, 0, NULL, NULL, 0, -1 };
		for (int i = 0; i < MAXSP && nsp < MAXSP; i++) if (sp[i].used) {
			for (int pass = 0; pass < 2; pass++) {                      /* pass 0: the entry in Spaces, pass 1: a second copy for Current Space when this is the shown space */
				if (pass == 1 && !(sp[i].shown && first < 0)) break;
				bp_node *a = &ints[ni++], *b = &ints[ni++], *t = &ints[ni++];
				*a = (bp_node){ BP_INT, NULL, sp[i].id, 0, NULL, NULL, 0, -1 }; *b = *a; *t = (bp_node){ BP_INT, NULL, sp[i].type, 0, NULL, NULL, 0, -1 };
				bp_node **kv = &kids[nk]; nk += 4; kv[0] = a; kv[1] = b; kv[2] = t; kv[3] = emptystr;
				bp_node *d = &dicts[nd++]; *d = (bp_node){ BP_DICT, NULL, 0, 0, kv, spkeyp, 4, -1 };
				if (pass == 0) spaces[nsp++] = d; else cur = d;
			}
			if (sp[i].shown && first < 0) first = i;
		}
		if (!cur && nsp) cur = spaces[0];
		static const char *dk[3] = { "Current Space", "Spaces", "Display Identifier" };
		bp_node dkey[3], *dkeyp[3]; for (int k = 0; k < 3; k++) { dkey[k] = (bp_node){ BP_STR, dk[k], 0, 0, NULL, NULL, 0, -1 }; dkeyp[k] = &dkey[k]; }
		arr = (bp_node){ BP_ARRAY, NULL, 0, 0, spaces, NULL, nsp, -1 };
		bp_node dispid = (bp_node){ BP_STR, DISPLAY_UUID, 0, 0, NULL, NULL, 0, -1 };
		bp_node *dv[3] = { cur ? cur : &arr, &arr, &dispid };
		disp = (bp_node){ BP_DICT, NULL, 0, 0, dv, dkeyp, 3, -1 };
		bp_node *tv[1] = { &disp }; top = (bp_node){ BP_ARRAY, NULL, 0, 0, tv, NULL, 1, -1 };
		(void)keys; (void)strs; (void)nk;
		uint8_t *pl = NULL; size_t pn = bp_serialize(&top, &pl);
		if (!pl || pn > 0x4000) { free(pl); return reply_simple(c->fd, h, 1000); }
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, (uint32_t)pn); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, (uint32_t)pn);
		struct iovec v[2] = { { m, sizeof m }, { pl, pn } };
		int rc = ws_ipc_send(c->fd, v, 2, NULL, 0);
		free(pl);
		return rc;
	}
	case SLS_MSG_SpaceCopyValues: {                                                /* id u64@0x20, size 0x28; reply complex 0x38: OOL bplist dictionary (id64, ManagedSpaceID, type, uuid; values stored by SpaceSetValues are returned as set); 1010 for an unknown space */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = sp_find(id);
		if (i < 0) return reply_simple(c->fd, h, 0x3f2);
		uint8_t *pl = NULL; size_t pn;
		if (sp[i].values && sp[i].vlen) { pl = malloc(sp[i].vlen); if (!pl) return reply_simple(c->fd, h, 1000); memcpy(pl, sp[i].values, sp[i].vlen); pn = sp[i].vlen; }
		else {
			static const char *k4[4] = { "id64", "ManagedSpaceID", "type", "uuid" };
			bp_node key[4], *keyp[4], v0 = { BP_INT, NULL, sp[i].id, 0, NULL, NULL, 0, -1 }, v1 = v0, v2 = { BP_INT, NULL, sp[i].type, 0, NULL, NULL, 0, -1 }, v3 = { BP_STR, "", 0, 0, NULL, NULL, 0, -1 };
			for (int k = 0; k < 4; k++) { key[k] = (bp_node){ BP_STR, k4[k], 0, 0, NULL, NULL, 0, -1 }; keyp[k] = &key[k]; }
			bp_node *vals[4] = { &v0, &v1, &v2, &v3 };
			bp_node d = { BP_DICT, NULL, 0, 0, vals, keyp, 4, -1 };
			pn = bp_serialize(&d, &pl);
		}
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, (uint32_t)pn); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, (uint32_t)pn);
		struct iovec v[2] = { { m, sizeof m }, { pl, pn } };
		int rc = ws_ipc_send(c->fd, v, 2, NULL, 0);
		free(pl);
		return rc;
	}
	case SLS_MSG_SpaceCopyOwners:                                                  /* id u64@0x20, size 0x28; reply complex 0x38 with an empty out-of-line array (no owners, recorded) */
	case SLS_MSG_SpaceCopyShape:                                                   /* the same, an empty shape */
	case SLS_MSG_SpaceCopyManagedShape: {                                          /* ... and the managed shape: the display rectangle as a serialized region */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		if (sp_find(id) < 0 && h->msgh_id != SLS_MSG_SpaceCopyOwners) return reply_simple(c->fd, h, 0x3f2);      /* an unknown space has no owners: an empty array (recorded) */
		uint8_t reg[128]; size_t rn = 0;
		if (h->msgh_id == SLS_MSG_SpaceCopyManagedShape) rn = ws_region_serialize(&(ws_rect){ 0, 0, wsd_screen_w, wsd_screen_h }, 1, reg, sizeof reg);
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, (uint32_t)rn); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, (uint32_t)rn);
		struct iovec v[2] = { { m, sizeof m }, { reg, rn } };
		return ws_ipc_send(c->fd, v, rn ? 2 : 1, NULL, 0);
	}
	case SLS_MSG_SpaceGetAbsoluteLevel: {                                          /* id u64@0x20, size 0x28; reply value 0 (recorded); 1010 for an unknown space */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		if (sp_find(id) < 0) return reply_simple(c->fd, h, 0x3f2);
		return reply_value(c->fd, h, 0);
	}
	case SLS_MSG_SpaceGetTransform: {                                              /* id u64@0x20, size 0x28; reply 0x40: ret, then the identity transform a b c d tx ty as floats and a flag byte 1 (recorded) */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		if (sp_find(id) < 0) return reply_simple(c->fd, h, 0x3f2);
		uint8_t r[0x40]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
		float one = 1.0f; memcpy(r + 0x24, &one, 4); memcpy(r + 0x30, &one, 4); r[0x3c] = 1;
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_CopyManagedDisplayForSpace: {                                     /* id u64@0x20, size 0x28; reply 0x34: the display's UUID (16 bytes); 1010 for an unknown space */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		if (sp_find(id) < 0) return reply_simple(c->fd, h, 0x3e9);                  /* recorded: 1001 */
		uint8_t r[0x34]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR); memcpy(r + 0x24, display_uuid_bytes, 16);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_SpaceGetRect: {                                                   /* id u64@0x20, size 0x28; reply 0x44: ret, then x y w h as doubles (the display rectangle, recorded) */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		if (sp_find(id) < 0) return reply_simple(c->fd, h, 1000);                   /* recorded */
		uint8_t r[0x44]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
		double w = wsd_screen_w, hh = wsd_screen_h; memcpy(r + 0x34, &w, 8); memcpy(r + 0x3c, &hh, 8);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_SpaceSetAlpha: {                                                  /* id u64@0x20, alpha float@0x28, size 0x2c; applied to a known space, always 0 */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = sp_find(id);
		if (i >= 0) { float a; memcpy(&a, buf + 0x28, 4); if (a != a) a = 1.0f; sp[i].alpha = a < 0 ? 0 : a > 1 ? 1 : a; }
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
