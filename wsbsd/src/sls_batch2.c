/* Small SkyLight routines with simple observable state, decompiled 1:1 (second batch). Every request is checked as in the MIG stub (header -304, descriptor type / size mismatch -300) and answered with the
 * retcode of the real routine. No client here holds the private entitlements, so the entitlement-gated ones fail the way the real server fails for an unentitled caller.
 *  30238 RemoveWindowCaptureExcludeShape  size 0x24, wid@0x20: with write access the exclude shape is dropped; 0 even for an unknown window
 *  30053 SetBackgroundEventMaskAndShape   complex 1 OOL, size 0x40: mask@0x34, OOL size = count@0x38 (-300), flags@0x3c bit 0 = a shape follows (a region; unparsable gives 1000); the mask loses the bits a caller without the
 *                                         event monitoring entitlement may not have (0xfffbf3ff); without the shape flag the stored shape is dropped
 *  30403 SetGlobalForceConfig             complex 1 OOL plist, size 0x38, count@0x34 (-300); empty clears the config, a plist that is not a dictionary gives 1000
 *  30392 SetPressureConfigurationOverride complex 1 OOL plist, size 0x40, device id u64@0x34 (non-0: 1001), count@0x3c; empty clears, a plist that is not a dictionary gives 1001
 *  30405 PackagesSetFindCursorPrefs       complex 1 OOL plist, size 0x38, count@0x34: no data or garbage 1001; a dictionary {GlobalDomain, Disabled} sets the session's (GlobalDomain true) or the connection's find-cursor switch; 0
 *  30065 SnappingInfoSetPrefs, 30239 SetApplicationBindingsForWorkspaces, 30256 SetPreferencesForWorkspaces: complex 1 OOL plist, size 0x38, count (-300); 0
 *  30318 ResetWindows                     complex 1 OOL window ids, size 0x38, count@0x34 = size / 4 (-300); 0
 *  30425 WindowListSetLockedBounds        complex 2 OOLs, size 0x4c: ids (size@0x28, count@0x44 = size / 4) and bounds (size@0x38, count@0x48 = size / 32), -300 for a mismatch; 0
 *  30153 SetDefaultBootstrapPort          complex, one port, size 0x28, disposition@0x26 must be 0x11 (-300); only a session agent may: 1010
 *  30499 SecureCursorPositionTakeAssertion size 0x18; needs a private entitlement: 1000
 *  29022 TBRelease (size 0x24)            needs an entitlement: 1002;   30464 HMDRelease (size 0x24): no such HMD: 1000
 *  29029 TBGetTotalUpdateCount, 30471 HMDGetTotalUpdateCount: size 0x18; reply 0x34: count u64@0x24 (0: no devices), time u64@0x2c
 *  30568 SetTransactionCompletion         complex, one port, size 0x38, disposition@0x26 0x11 (-300); a null / dead port gives 1002; 0 */
#include "wsd_priv.h"
#include "ws_region.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAX_CONN_STATE 64
static struct { int used; uint32_t id, bg_mask; int bg_shape; int force_set, press_set, findcursor_off; } cs[MAX_CONN_STATE];
static int session_findcursor_disabled;
static int global_force_set, press_override_set;

static int cs_find(uint32_t id, int create)
{
	for (int i = 0; i < MAX_CONN_STATE; i++) if (cs[i].used && cs[i].id == id) return i;
	if (!create) return -1;
	for (int i = 0; i < MAX_CONN_STATE; i++) if (!cs[i].used) { memset(&cs[i], 0, sizeof cs[i]); cs[i].used = 1; cs[i].id = id; return i; }
	return -1;
}
void sls_batch2_owner_cleanup(uint32_t owner) { int i = cs_find(owner, 0); if (i >= 0) cs[i].used = 0; }

/* ---- a minimal bplist00 reader: the kind of the top object and booleans of a top-level dictionary with ASCII keys ---- */
static uint64_t be(const uint8_t *p, int n) { uint64_t v = 0; while (n-- > 0) v = v << 8 | *p++; return v; }
static int bpl_top(const uint8_t *b, size_t n, size_t *off, int *osz, int *rsz, uint64_t *nobj, const uint8_t **tab)
{
	if (n < 8 + 1 + 32 || memcmp(b, "bplist00", 8)) return -1;
	const uint8_t *t = b + n - 32;
	*osz = t[6]; *rsz = t[7]; *nobj = be(t + 8, 8); uint64_t top = be(t + 16, 8), toff = be(t + 24, 8);
	if (*osz < 1 || *osz > 8 || *rsz < 1 || *rsz > 8 || !*nobj || top >= *nobj || toff < 9 || toff > n - 32 || (n - 32 - toff) / (uint64_t)*osz < *nobj) return -1;
	*tab = b + toff;
	uint64_t o = be(*tab + top * (uint64_t)*osz, *osz); if (o < 8 || o >= n - 32) return -1;
	*off = o; return b[o] >> 4;
}
static int bpl_kind(const uint8_t *b, size_t n) { size_t o; int os, rs; uint64_t no; const uint8_t *tab; return bpl_top(b, n, &o, &os, &rs, &no, &tab); }
static int bpl_obj_str(const uint8_t *b, size_t n, const uint8_t *tab, int os, uint64_t no, uint64_t ref, char *out, size_t cap)
{
	if (ref >= no) return 0; uint64_t o = be(tab + ref * (uint64_t)os, os); if (o >= n - 32 || (b[o] >> 4) != 5) return 0;
	size_t l = b[o] & 15, hd = 1; if (l == 15) return 0; if (o + hd + l > n - 32 || l + 1 > cap) return 0;
	memcpy(out, b + o + hd, l); out[l] = 0; return 1;
}
static int bpl_dict_bool(const uint8_t *b, size_t n, const char *key, int *val)           /* 1 found as a boolean, 0 missing / other type */
{
	size_t o; int os, rs; uint64_t no; const uint8_t *tab;
	if (bpl_top(b, n, &o, &os, &rs, &no, &tab) != 0xd) return 0;
	size_t cnt = b[o] & 15, hd = 1; if (cnt == 15) return 0;
	if (o + hd + cnt * 2 * (size_t)rs > n - 32) return 0;
	for (size_t i = 0; i < cnt; i++) {
		char k[64]; if (!bpl_obj_str(b, n, tab, os, no, be(b + o + hd + i * rs, rs), k, sizeof k) || strcmp(k, key)) continue;
		uint64_t vr = be(b + o + hd + (cnt + i) * rs, rs); if (vr >= no) return 0;
		uint64_t vo = be(tab + vr * (uint64_t)os, os); if (vo >= n - 32) return 0;
		if (b[vo] == 0x08 || b[vo] == 0x09) { *val = b[vo] == 0x09; return 1; }
		return 0;
	}
	return 0;
}

/* one OOL descriptor at 0x1c: validates a complex request (header -304, type / count -300); the data follows the message. Returns the data size or -1 with the reply sent through *err */
static int ool1(const mach_msg_header_t *h, const uint8_t *buf, size_t len, uint32_t want, size_t cntoff, int *err)
{
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != want || len < want || rd32(buf, 0x18) != 1) { *err = -304; return -1; }
	uint32_t osz = rd32(buf, 0x28);
	if (buf[0x27] != 1 || osz != rd32(buf, cntoff)) { *err = -300; return -1; }
	if (len != (size_t)want + osz) { *err = -304; return -1; }
	return (int)osz;
}
static uint64_t real_time(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return (uint64_t)ts.tv_sec * 1000000000ull + (uint64_t)ts.tv_nsec; }

int sls_batch2_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	int err, osz;
	switch (h->msgh_id) {
	case 30238: {
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (wid && ws_window_exists(srv, wid) && holds_rights(c, wid)) ws_set_window_capture_exclude(srv, wid, NULL, 0);
		return reply_simple(c->fd, h, 0);
	}
	case 30053: {
		if ((osz = ool1(h, buf, len, 0x40, 0x38, &err)) < 0) return reply_simple(c->fd, h, err);
		uint32_t mask = rd32(buf, 0x34); int shaped = buf[0x3c] & 1;
		if (shaped && osz) { ws_rect *rc = NULL; int nr = 0; ws_rect bb; int pr = ws_region_parse(buf + 0x40, (uint32_t)osz, &rc, &nr, &bb); free(rc); if (pr != 0) return reply_simple(c->fd, h, 1000); }
		int i = cs_find(c->id, 1); if (i < 0) return reply_simple(c->fd, h, 1000);
		cs[i].bg_shape = shaped && osz; cs[i].bg_mask = mask & 0xfffbf3ffu;
		return reply_simple(c->fd, h, 0);
	}
	case 30403: {
		if ((osz = ool1(h, buf, len, 0x38, 0x34, &err)) < 0) return reply_simple(c->fd, h, err);
		if (!osz) { global_force_set = 0; return reply_simple(c->fd, h, 0); }
		if (bpl_kind(buf + 0x38, (size_t)osz) != 0xd) return reply_simple(c->fd, h, 1000);
		global_force_set = 1; return reply_simple(c->fd, h, 0);
	}
	case 30392: {
		if ((osz = ool1(h, buf, len, 0x40, 0x3c, &err)) < 0) return reply_simple(c->fd, h, err);
		uint64_t dev; memcpy(&dev, buf + 0x34, 8);
		if (dev) return reply_simple(c->fd, h, 1001);
		if (!osz) { press_override_set = 0; return reply_simple(c->fd, h, 0); }
		if (bpl_kind(buf + 0x40, (size_t)osz) != 0xd) return reply_simple(c->fd, h, 1001);
		press_override_set = 1; return reply_simple(c->fd, h, 0);
	}
	case 30405: {
		if ((osz = ool1(h, buf, len, 0x38, 0x34, &err)) < 0) return reply_simple(c->fd, h, err);
		if (!osz || bpl_kind(buf + 0x38, (size_t)osz) < 0) return reply_simple(c->fd, h, 1001);
		if (bpl_kind(buf + 0x38, (size_t)osz) == 0xd) {
			int g = 0, d = 0; bpl_dict_bool(buf + 0x38, (size_t)osz, "GlobalDomain", &g); bpl_dict_bool(buf + 0x38, (size_t)osz, "Disabled", &d);
			if (g) session_findcursor_disabled = d;
			else { int i = cs_find(c->id, 1); if (i >= 0) cs[i].findcursor_off = d; }
		}
		return reply_simple(c->fd, h, 0);
	}
	case 30065: case 30239: case 30256:
		if ((osz = ool1(h, buf, len, 0x38, 0x34, &err)) < 0) return reply_simple(c->fd, h, err);
		return reply_simple(c->fd, h, 0);
	case 30318: {
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x38 || len < 0x38 || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
		uint32_t sz = rd32(buf, 0x28);
		if (buf[0x27] != 1 || (sz >> 2) != rd32(buf, 0x34)) return reply_simple(c->fd, h, -300);
		if (len != 0x38 + (size_t)sz) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0);
	}
	case 30425: {
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x4c || len < 0x4c || rd32(buf, 0x18) != 2) return reply_simple(c->fd, h, -304);
		uint32_t a = rd32(buf, 0x28), b = rd32(buf, 0x38);
		if (buf[0x27] != 1 || buf[0x37] != 1 || (a >> 2) != rd32(buf, 0x44) || (b >> 5) != rd32(buf, 0x48)) return reply_simple(c->fd, h, -300);
		if (len != 0x4c + (size_t)a + b) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0);
	}
	case 30153:
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x28 || len < 0x28 || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
		if (buf[0x26] != 0x11 || buf[0x27] != 0) return reply_simple(c->fd, h, -300);
		return reply_simple(c->fd, h, 1010);
	case 30499:
		if (!simple_ok(h, len, 0x18)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 1000);
	case 29022:
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 1002);
	case 30464:
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 1000);
	case 29029: case 30471: {
		if (!simple_ok(h, len, 0x18)) return reply_simple(c->fd, h, -304);
		uint8_t r[0x34]; memset(r, 0, sizeof r); fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0); memcpy(r + 0x18, &WS_NDR, 8);
		uint64_t t = real_time(); memcpy(r + 0x2c, &t, 8);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case 30568: {
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x38 || len < 0x38 || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
		if (buf[0x26] != 0x11 || buf[0x27] != 0) return reply_simple(c->fd, h, -300);
		uint32_t port = rd32(buf, 0x1c);
		if (port == 0 || port == 0xffffffffu) return reply_simple(c->fd, h, 1002);
		return reply_simple(c->fd, h, 0);
	}
	}
	return -2;
}
