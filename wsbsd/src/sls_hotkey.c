/* Hot keys: the per-connection ones (GetHotKey, SetHotKey, ...Enabled, ...Type, RemoveHotKey), the per-connection operating mode and the session's symbolic hot key table
 * (value + enabled bit for ids 0..0x108). Layouts from the decompiled routines. The hot key records are kept; events are not matched against them yet. */
#include "wsd_priv.h"
#include <string.h>

#define MAXHK 256
#define NSYM 0x109
static struct { int used; uint32_t owner; uint64_t id; uint16_t key, mods; uint32_t flags, type; int disabled; } hk[MAXHK];
static struct { uint32_t owner; uint32_t mode; int used; } hkmode[64];
static struct { int valid; uint16_t key, mods; uint32_t flags; int enabled; } sym[NSYM];

static int hk_find(uint32_t owner, uint64_t id) { for (int i = 0; i < MAXHK; i++) if (hk[i].used && hk[i].owner == owner && hk[i].id == id) return i; return -1; }

int sls_symbolic_hotkey(uint32_t id, uint16_t *key, uint16_t *mods, uint32_t *flags, int *enabled)
{
	if (id >= NSYM) return -1;
	if (key) *key = sym[id].key;
	if (mods) *mods = sym[id].mods;
	if (flags) *flags = sym[id].flags;
	if (enabled) *enabled = sym[id].enabled;
	return sym[id].valid ? 0 : 1;
}

void sls_hotkey_owner_cleanup(uint32_t owner)
{
	for (int i = 0; i < MAXHK; i++) if (hk[i].used && hk[i].owner == owner) hk[i].used = 0;
	for (int i = 0; i < 64; i++) if (hkmode[i].used && hkmode[i].owner == owner) hkmode[i].used = 0;
}

static int reply_u32x3(conn *c, const mach_msg_header_t *h, uint32_t a, uint32_t b, uint32_t d)
{
	uint8_t r[0x30]; memset(r, 0, sizeof r);
	fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
	memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
	wr32(r, 0x24, a); wr32(r, 0x28, b); wr32(r, 0x2c, d);
	return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
}

int sls_hotkey_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	switch (h->msgh_id) {
	case SLS_MSG_GetHotKey: {                                                      /* id u64@0x20, size 0x28; reply 0x30: key, modifiers, flags; 1007 when unknown */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = hk_find(c->id, id);
		if (i < 0) return reply_simple(c->fd, h, 0x3ef);
		return reply_u32x3(c, h, hk[i].key, hk[i].mods, hk[i].flags);
	}
	case SLS_MSG_SetHotKey: {                                                      /* id u64@0x20, key@0x28 (low 16), modifiers@0x2c (low 16), flags@0x30, @0x34; size 0x38; 0 */
		if (!simple_ok(h, len, 0x38)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = hk_find(c->id, id);
		for (int k = 0; k < MAXHK && i < 0; k++) if (!hk[k].used) i = k;
		if (i < 0) return reply_simple(c->fd, h, 1000);
		hk[i].used = 1; hk[i].owner = c->id; hk[i].id = id; hk[i].key = (uint16_t)rd32(buf, 0x28); hk[i].mods = (uint16_t)rd32(buf, 0x2c); hk[i].flags = rd32(buf, 0x30);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetHotKeyEnabled: {                                               /* id@0x20, size 0x28; reply value 1 when enabled, 0 when disabled or unknown */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = hk_find(c->id, id);
		return reply_value(c->fd, h, i >= 0 && !hk[i].disabled);
	}
	case SLS_MSG_SetHotKeyEnabled: {                                               /* id@0x20, enabled@0x28, size 0x2c; 1007 when unknown */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = hk_find(c->id, id);
		if (i < 0) return reply_simple(c->fd, h, 0x3ef);
		hk[i].disabled = rd32(buf, 0x28) == 0;
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_RemoveHotKey: {                                                   /* id@0x20, size 0x28; 0 (1007 when unknown) */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = hk_find(c->id, id);
		if (i < 0) return reply_simple(c->fd, h, 0x3ef);
		hk[i].used = 0;
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetHotKeyType: {                                                  /* id@0x20, size 0x28; reply value type & 0x1f; 1007 when unknown */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = hk_find(c->id, id);
		if (i < 0) return reply_simple(c->fd, h, 0x3ef);
		return reply_value(c->fd, h, (int32_t)(hk[i].type & 0x1f));
	}
	case SLS_MSG_SetHotKeyType: {                                                  /* id@0x20, type@0x28, size 0x2c; the type keeps its bits 1,2,3,5,6 and takes bits 0 and 4 from the request */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		int i = hk_find(c->id, id);
		if (i < 0) return reply_simple(c->fd, h, 0x3ef);
		hk[i].type = (hk[i].type & 0x6e) | (rd32(buf, 0x28) & 0x11);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetGlobalHotKeyOperatingMode: {                                   /* mode@0x20, size 0x24: per connection; 0 */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		int slot = -1;
		for (int i = 0; i < 64; i++) if (hkmode[i].used && hkmode[i].owner == c->id) slot = i;
		for (int i = 0; i < 64 && slot < 0; i++) if (!hkmode[i].used) slot = i;
		if (slot >= 0) { hkmode[slot].used = 1; hkmode[slot].owner = c->id; hkmode[slot].mode = rd32(buf, 0x20); }
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetGlobalHotKeyOperatingMode: {                                   /* size 0x18 (header only); reply value: this connection's mode OR the session's (0 here) */
		if (!simple_ok(h, len, 0x18)) return reply_simple(c->fd, h, -304);
		uint32_t m = 0;
		for (int i = 0; i < 64; i++) if (hkmode[i].used && hkmode[i].owner == c->id) m = hkmode[i].mode;
		return reply_value(c->fd, h, (int32_t)m);
	}
	case SLS_MSG_GetSymbolicHotKeyValue: {                                         /* id@0x20, size 0x24; reply 0x30: key, modifiers, flags; 1007 when the id is out of range or has no value */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t id = rd32(buf, 0x20);
		if (id >= NSYM || !sym[id].valid) return reply_simple(c->fd, h, 0x3ef);
		return reply_u32x3(c, h, sym[id].key, sym[id].mods, sym[id].flags);
	}
	case SLS_MSG_SetSymbolicHotKeyValue: {                                         /* id@0x20, key@0x24, modifiers@0x28 (low 16 bits each), flags@0x2c, size 0x30; 0 for a valid id */
		if (!simple_ok(h, len, 0x30)) return reply_simple(c->fd, h, -304);
		uint32_t id = rd32(buf, 0x20);
		if (id >= NSYM) return reply_simple(c->fd, h, 0x3e9);
		sym[id].valid = 1; sym[id].key = (uint16_t)rd32(buf, 0x24); sym[id].mods = (uint16_t)rd32(buf, 0x28); sym[id].flags = rd32(buf, 0x2c);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_IsSymbolicHotKeyEnabled: {                                        /* id@0x20, size 0x24; reply value */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t id = rd32(buf, 0x20);
		return reply_value(c->fd, h, id < NSYM && sym[id].enabled);
	}
	case SLS_MSG_SetSymbolicHotKeyEnabled: {                                       /* id@0x20, enabled@0x24, size 0x28; 1001 for an id out of range */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t id = rd32(buf, 0x20);
		if (id >= NSYM) return reply_simple(c->fd, h, 0x3e9);
		sym[id].enabled = rd32(buf, 0x24) != 0;
		return reply_simple(c->fd, h, 0);
	}
	}
	return -2;
}
