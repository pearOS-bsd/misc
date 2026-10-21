/* Window routines beyond the core set in wsd.c: properties, layer context binding, ordered-in query. */
#include <math.h>
#include "wsd_priv.h"
#include "bplist.h"
#include "ws_region.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* window properties: name -> serialized property list bytes (kept opaque) */
#define MAXPROPS 512
static struct { int used; uint32_t wid; char key[130]; uint8_t *data; uint32_t len; } props[MAXPROPS];
static struct { int used; uint32_t wid, ctx; } layer_ctx[256];

/* a copy of a named window value (SetWindowProperty); the length, or -1 when the window has no such value */
int sls_window_property_copy(uint32_t wid, const char *key, uint8_t *out, size_t cap)
{
	for (int i = 0; i < MAXPROPS; i++) if (props[i].used && props[i].wid == wid && !strcmp(props[i].key, key)) { if (props[i].len > cap) return -1; if (props[i].len) memcpy(out, props[i].data, props[i].len); return (int)props[i].len; }
	return -1;
}

static void purge_dead(void)
{
	for (int i = 0; i < MAXPROPS; i++) if (props[i].used && !ws_window_exists(srv, props[i].wid)) { free(props[i].data); memset(&props[i], 0, sizeof props[i]); }
	for (int i = 0; i < 256; i++) if (layer_ctx[i].used && !ws_window_exists(srv, layer_ctx[i].wid)) layer_ctx[i].used = 0;
}

static int prop_name(const uint8_t *buf, size_t off, uint32_t n, char *out) { memcpy(out, buf + off, n); out[n] = 0; out[strnlen(out, n)] = 0; return 1; }

/* SetWindowProperty 30048: complex, OOL data@0x1c (size@0x28), NDR@0x2c, wid@0x34, name offset@0x38, name length@0x3c (<= 0x80), name@0x40, then the data size again.
 * Replies: 0; 1000 for an unknown window; -300 if the repeated size differs from the descriptor's. */
static int do_set_property(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len < 0x44 || h->msgh_size < 0x44 || h->msgh_size > 0xc4 || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
	if (buf[0x27] != 1) return reply_simple(c->fd, h, -300);
	uint32_t osz = rd32(buf, 0x28), n = rd32(buf, 0x3c), P = (n + 3) & ~3u;
	if (n > 0x80 || h->msgh_size != P + 0x44 || len != (size_t)h->msgh_size + osz) return reply_simple(c->fd, h, -304);
	if (rd32(buf, 0x40 + P) != osz) return reply_simple(c->fd, h, -300);
	uint32_t wid = rd32(buf, 0x34);
	if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 1000);
	char key[130]; prop_name(buf, 0x40, n, key);
	purge_dead();
	int slot = -1;
	for (int i = 0; i < MAXPROPS; i++) if (props[i].used && props[i].wid == wid && !strcmp(props[i].key, key)) { slot = i; free(props[i].data); props[i].data = NULL; break; }
	if (slot < 0) {                                                                  /* a new entry: no connection may hold more than 64 of the shared table's 512 */
		int mine = 0; uint32_t ow = ws_window_owner(srv, wid);
		for (int i = 0; i < MAXPROPS; i++) if (props[i].used && ws_window_owner(srv, props[i].wid) == ow) mine++;
		if (mine >= 64) return reply_simple(c->fd, h, 1000);
	}
	for (int i = 0; i < MAXPROPS && slot < 0; i++) if (!props[i].used) slot = i;
	if (slot < 0) return reply_simple(c->fd, h, 1000);
	uint8_t *d = osz ? malloc(osz) : NULL;
	if (osz && !d) return reply_simple(c->fd, h, 1000);
	if (osz) memcpy(d, buf + h->msgh_size, osz);
	props[slot].used = 1; props[slot].wid = wid; snprintf(props[slot].key, sizeof props[slot].key, "%s", key); props[slot].data = d; props[slot].len = osz;
	return reply_simple(c->fd, h, 0);
}

/* the name requests: wid@0x20, offset@0x24, length@0x28 (<= 0x80), name@0x2c; size = pad4(length) + 0x2c */
static int name_request(const mach_msg_header_t *h, const uint8_t *buf, size_t len, uint32_t extra, char *key, uint32_t *wid)
{
	if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x2c || h->msgh_size > 0xac + extra) return 0;
	uint32_t n = rd32(buf, 0x28);
	if (n > 0x80 || h->msgh_size != ((n + 3) & ~3u) + 0x2c + extra) return 0;
	*wid = rd32(buf, 0x20); prop_name(buf, 0x2c, n, key);
	return 1;
}

static int do_get_property(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	char key[130]; uint32_t wid;
	if (!name_request(h, buf, len, 0, key, &wid)) return reply_simple(c->fd, h, -304);
	if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 1000);
	const uint8_t *data = NULL; uint32_t n = 0;
	for (int i = 0; i < MAXPROPS; i++) if (props[i].used && props[i].wid == wid && !strcmp(props[i].key, key)) { data = props[i].data; n = props[i].len; }
	uint8_t m[0x38]; memset(m, 0, sizeof m);
	fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
	wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, n);                 /* one OOL descriptor, then the record and the size */
	memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, n);
	struct iovec v[2] = { { m, sizeof m }, { (void *)data, n } };
	return ws_ipc_send(c->fd, v, n ? 2 : 1, NULL, 0);
}

static int do_delete_property(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	char key[130]; uint32_t wid;
	if (!name_request(h, buf, len, 0, key, &wid)) return reply_simple(c->fd, h, -304);
	for (int i = 0; i < MAXPROPS; i++) if (props[i].used && props[i].wid == wid && !strcmp(props[i].key, key)) { free(props[i].data); memset(&props[i], 0, sizeof props[i]); }
	return reply_simple(c->fd, h, 0);
}

/* per-window shapes kept for screen capture (exclude) and for the pointer (cursor restriction); kind 0 = capture exclude, 1 = cursor restriction */
#define MAXSHAPES 256
static struct { uint32_t wid; int kind, n; ws_rect *r; } shapes[MAXSHAPES];
static void shape_store(int kind, uint32_t wid, ws_rect *r, int n)
{
	int slot = -1;
	for (int i = 0; i < MAXSHAPES; i++) { if (shapes[i].wid == wid && shapes[i].kind == kind && shapes[i].wid) { slot = i; break; } if (!shapes[i].wid && slot < 0) slot = i; }
	if (slot < 0) { free(r); return; }
	free(shapes[slot].r); shapes[slot].r = NULL; shapes[slot].n = 0;
	if (!n) { shapes[slot].wid = 0; free(r); return; }
	shapes[slot].wid = wid; shapes[slot].kind = kind; shapes[slot].r = r; shapes[slot].n = n;
}
int sls_window_shape(int kind, uint32_t wid, const ws_rect **r) { for (int i = 0; i < MAXSHAPES; i++) if (shapes[i].wid == wid && shapes[i].kind == kind) { *r = shapes[i].r; return shapes[i].n; } return 0; }

/* complex requests with one OOL descriptor (count@0x18 = 1, type byte@0x27 = 1, size@0x28), NDR@0x2c; returns the checked descriptor size or -1 with *err set */
int ool_request(const mach_msg_header_t *h, const uint8_t *buf, size_t len, uint32_t want_size, int *err)
{
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != want_size || len < want_size || rd32(buf, 0x18) != 1) { *err = -304; return -1; }
	uint32_t osz = rd32(buf, 0x28);
	if (buf[0x27] != 1) { *err = -300; return -1; }
	if (len != (size_t)want_size + osz) { *err = -304; return -1; }
	return (int)osz;
}


/* complex requests with n OOL descriptors (count@0x18 = n, 16 bytes each from 0x1c: type byte at +0xb, size at +0xc); the data follows the message in descriptor order.
 * Returns 0 with off[i] / sz[i] set, else a MIG error code. */
static int ool_multi(const mach_msg_header_t *h, const uint8_t *buf, size_t len, uint32_t want_size, int n, size_t *off, uint32_t *sz)
{
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != want_size || len < want_size || rd32(buf, 0x18) != (uint32_t)n) return -304;
	uint64_t total = want_size;
	for (int i = 0; i < n; i++) { if (buf[0x27 + 16 * i] != 1) return -300; sz[i] = rd32(buf, 0x28 + 16 * i); off[i] = (size_t)total; total += sz[i]; }
	return total == len ? 0 : -304;
}

/* Core Image filters (NewCIFilter / ReleaseCIFilter / SetCIFilterValues / SetWindowCIFilter): the filter is named by a property list string, "CIShapedWaterRipple" (type 1) or "CIColorInvert" (type 2) as the decompile compares it; kept per connection and per window, not rendered */
#define MAXCIF 128
static struct { uint32_t id, owner; int type; uint32_t refs; } cif[MAXCIF];
static uint32_t next_cif = 1;
static struct { uint32_t wid, fid; } win_cif[256];
static int cif_find(uint32_t id) { for (int i = 0; i < MAXCIF; i++) if (cif[i].id == id) return i; return -1; }

static uint32_t mouse_enable[64]; static uint32_t mouse_enable_wid[64];
extern int wsd_screen_w, wsd_screen_h;
static float zoom_scale = 1.0f; static int32_t zoom_x = INT32_MIN, zoom_y = INT32_MIN; static uint32_t zoom_flag;
static uint32_t menubar_style; static uint8_t menubar_autohide, menubar_blurred;      /* menu bar state (a menu bar always exists on wsd's single display) */

/* per-window attributes the simple setters keep: depth, one-shot flag, backing alpha, autofill colour, client perceived type */
#define MAXATTR 512
static struct { uint32_t wid; int depth; uint8_t oneshot, has_alpha, have_alpha; uint8_t autofill[12]; int perceived; } attr[MAXATTR];
static int attr_slot(uint32_t wid, int create)
{
	int free_i = -1;
	for (int i = 0; i < MAXATTR; i++) { if (attr[i].wid == wid) return i; if (free_i < 0 && (!attr[i].wid || !ws_window_exists(srv, attr[i].wid))) free_i = i; }
	if (!create || free_i < 0) return -1;
	memset(&attr[free_i], 0, sizeof attr[free_i]); attr[free_i].wid = wid; return free_i;
}

extern uint32_t cursor_lock_owner;
static uint8_t cursor_drag_lock[31]; static uint32_t cursor_restriction_mode; static uint8_t cursor_restriction_corners, cursor_teleport;

static float cursor_scale = 1.0f;
#define MAXXF 256
static struct { uint32_t wid; float m[6]; } xform[MAXXF];                  /* SetWindowTransform: kept per window (not applied when compositing) */
#define MAXCP 256
static struct { uint32_t wid; uint32_t profile; } cprof[MAXCP];                  /* SetWindowColorProfile: the profile id per window (0 = unset) */
#define MAXWC 256
static struct { uint32_t wid; double v[6]; } wcon[MAXWC];                         /* PackagesSetWindowConstraints: six doubles per window */
#define MAXSR 256
static struct { uint32_t wid, sid; float scale; } sres[MAXSR];                  /* SetSurfaceResolution: the scale per surface (unset surfaces count as 1) */
static int surface_of(uint32_t wid, uint32_t sid) { uint32_t ids[0x400]; int n = wsd_window_surfaces(wid, ids, 0x400); if (n > 0x400) n = 0x400; for (int i = 0; i < n; i++) if (ids[i] == sid) return 1; return 0; }
int sls_window_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	switch (h->msgh_id) {
	case SLS_MSG_InvalidateWindowShadow: {                                        /* wid@0x20; 0 whatever the window (decompiled: the invalidation only happens with rights) */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (ws_window_exists(srv, wid) && holds_rights(c, wid)) ws_window_invalidate_shadow(srv, wid);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SynchronizeWindowBackingStore:                                   /* wid@0x20: waits for the next display update; answered at once here */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0);
	case SLS_MSG_RemoveAllSurfaces:
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, wsd_remove_all_surfaces(c, rd32(buf, 0x20)));
	case SLS_MSG_GetSurfaceCount:                                                  /* wid@0x20, size 0x24; reply 0x28 with the number of surfaces; 1000 for an unknown window */
	case SLS_MSG_GetSurfaceList: {                                                 /* reply 0x28 + 4n: n@0x24, the ids from 0x28 (at most 0x400) */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 1000);
		uint32_t ids[0x400]; int n = wsd_window_surfaces(wid, ids, 0x400); if (n > 0x400) n = 0x400;
		if (h->msgh_id == SLS_MSG_GetSurfaceCount) return reply_value(c->fd, h, n);
		uint8_t r[0x28 + 4 * 0x400]; memset(r, 0, 0x28);
		uint32_t size = 0x28 + 4 * (uint32_t)n;
		fill_reply_header((mach_msg_header_t *)r, h, size, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR); wr32(r, 0x24, (uint32_t)n);
		for (int i = 0; i < n; i++) wr32(r, 0x28 + 4 * i, ids[i]);
		return ws_ipc_send(c->fd, &(struct iovec){ r, size }, 1, NULL, 0);
	}
	case SLS_MSG_GetScreenRectForWindow: {                                         /* wid@0x20; reply 0x34: retcode, x y w h as floats; 1000 for an unknown window */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		ws_rect f;
		if (ws_window_frame(srv, rd32(buf, 0x20), &f)) return reply_simple(c->fd, h, 1000);
		uint8_t r[0x34]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
		float v[4] = { (float)f.x, (float)f.y, (float)f.w, (float)f.h }; memcpy(r + 0x24, v, 16);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_ShapeWindow: {                                                    /* two OOL regions (shape, second shape), wid@0x44, option@0x48, byte@0x4c, sizes repeated @0x50/@0x54, size 0x58 */
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x58 || len < 0x58 || rd32(buf, 0x18) != 2) return reply_simple(c->fd, h, -304);
		uint32_t s1 = rd32(buf, 0x28), s2 = rd32(buf, 0x38);
		if (buf[0x27] != 1 || buf[0x37] != 1 || s1 != rd32(buf, 0x50) || s2 != rd32(buf, 0x54)) return reply_simple(c->fd, h, -300);
		if (len != 0x58 + (size_t)s1 + s2) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x44);
		if (holds_rights(c, wid) && s1) {
			ws_rect *r = NULL; int nr = 0; ws_rect bb;
			if (ws_region_parse(buf + 0x58, s1, &r, &nr, &bb) == 0 && bb.w > 0 && bb.h > 0) { ws_set_window_frame(srv, wid, bb.x, bb.y, bb.w, bb.h); ws_set_window_shape(srv, wid, r, nr); }   /* the shape is in screen coordinates: its bounds are the new frame (verified live), and it is the new shape: a window that grew took events only where it had been */
			free(r);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowResolution: {                                           /* wid@0x20, float@0x24 */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20); uint32_t bits = rd32(buf, 0x24); float f; memcpy(&f, &bits, 4);
		if (!ws_window_exists(srv, wid) || !holds_rights(c, wid)) return -2;       /* what the real server answers for a window it does not let us change (recorded) */
		ws_set_window_resolution(srv, wid, f);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetWindowResolution: {                                           /* wid@0x20; reply 0x28 with the float@0x24 */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		float f;
		if (ws_window_resolution(srv, rd32(buf, 0x20), &f)) return -2;
		uint32_t bits; memcpy(&bits, &f, 4);
		return reply_value(c->fd, h, (int32_t)bits);
	}
	case SLS_MSG_GetWindowClipShape:                                                /* the same reply with the shape relative to the window (recorded on a macOS runner) */
	case SLS_MSG_GetWindowShape: {                                                 /* wid@0x20; reply complex 0x38 with the serialized shape in screen coordinates; 1000 for an unknown window */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		ws_rect f;
		if (ws_window_frame(srv, rd32(buf, 0x20), &f)) return reply_simple(c->fd, h, 1000);
		ws_rect r = h->msgh_id == SLS_MSG_GetWindowClipShape ? (ws_rect){ 0, 0, f.w, f.h } : f; uint8_t reg[256];
		size_t n = ws_region_serialize(&r, 1, reg, sizeof reg);
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, (uint32_t)n); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, (uint32_t)n);
		struct iovec v[2] = { { m, sizeof m }, { reg, n } };
		return ws_ipc_send(c->fd, v, 2, NULL, 0);
	}
	case SLS_MSG_GetWindowListWithTags: {                                          /* owner@0x20 (0: all), max@0x24 (<= 0x400), option byte@0x28 (bit 0: on screen only), tag masks @0x2c/@0x34 (no tags yet); size 0x3c */
		if (!simple_ok(h, len, 0x3c)) return reply_simple(c->fd, h, -304);
		uint32_t owner = rd32(buf, 0x20), max = rd32(buf, 0x24);
		if (max > 0x400) max = 0x400;
		ws_wid ids[0x400];
		int total = ws_list_windows(srv, owner, buf[0x28] & 1, ids, (int)max);
		uint32_t n = (uint32_t)total < max ? (uint32_t)total : max;
		uint8_t m[0x2c + 4 * 0x400]; memset(m, 0, 0x2c);
		fill_reply_header((mach_msg_header_t *)m, h, 0x2c + 4 * n, 0);
		memcpy(m + 0x18, &WS_NDR, 8); wr32(m, 0x20, 0); wr32(m, 0x24, n);
		for (uint32_t i = 0; i < n; i++) wr32(m, 0x28 + 4 * i, ids[i]);
		wr32(m, 0x28 + 4 * n, (uint32_t)total);
		struct iovec v = { m, 0x2c + 4 * n };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case 30475: {                                                      /* __XSetWindowCursorRestrictionShape: OOL region, wid@0x34, region size repeated@0x38, size 0x3c (-304 / -300 as everywhere); answers 1001 for an unknown window, 1002 without rights (a non-empty region replaces the window's, an empty one removes it). The restriction is kept but not yet applied to the pointer (the flags that make it active were not decompiled). */
		int err; int osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		uint32_t wid = rd32(buf, 0x34); int restrict_shape = 1;
		if (restrict_shape && (!wid || !ws_window_exists(srv, wid))) return reply_simple(c->fd, h, 1001);
		if (restrict_shape && !holds_rights(c, wid)) return reply_simple(c->fd, h, 1002);
		ws_rect *rc = NULL; int nr = 0; ws_rect bb;
		if (osz && ws_region_parse(buf + 0x3c, (uint32_t)osz, &rc, &nr, &bb) != 0) { free(rc); rc = NULL; nr = 0; }
		shape_store(restrict_shape ? 1 : 0, wid, rc, nr);
		return reply_simple(c->fd, h, 0);
	}
	case 30486:                                                                    /* __XSetZoomDisplay: size 0x24 (display@0x20); only the session owner may (we are it): the screen zoom is reset, reply 0 */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0);
	case SLS_MSG_SetWindowOpaqueShape: {                                           /* OOL region, wid@0x34, region size@0x38 (= descriptor size), size 0x3c */
		int err; int osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		(void)holds_rights(c, rd32(buf, 0x34));                                     /* the opaque shape only helps the compositor skip work: accepted, not used yet */
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_AddStructuralRegionOfType: {                                      /* OOL region; type@0x34 (bit 0: tracking), wid@0x38, user data u64@0x3c, region size repeated@0x48, id u64@0x50; size 0x58 */
		int err; int osz = ool_request(h, buf, len, 0x58, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x48)) return reply_simple(c->fd, h, -300);
		uint32_t type = rd32(buf, 0x34), wid = rd32(buf, 0x38); uint64_t id; memcpy(&id, buf + 0x50, 8);
		if (type >= 2) return reply_simple(c->fd, h, 0x3f2);
		if (type & 1) {                                                             /* a tracking region: the pointer entering/leaving it is reported */
			ws_rect *rc = NULL; int nr = 0; ws_rect bb;
			if (osz && ws_region_parse(buf + 0x58, (uint32_t)osz, &rc, &nr, &bb) == 0 && holds_rights(c, wid)) ws_tracking_set(srv, id, wid, rc, nr);
			free(rc);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetCursorRegionLock: {                                            /* OOL region; size repeated@0x34; size 0x38. The pointer is kept inside the region's bounds; an empty region releases. 1004 when another connection holds the lock */
		int err; int osz = ool_request(h, buf, len, 0x38, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x34)) return reply_simple(c->fd, h, -300);
		if (cursor_lock_owner && cursor_lock_owner != c->id) return reply_simple(c->fd, h, 0x3ec);
		ws_rect *rc = NULL; int nr = 0; ws_rect bb;
		if (osz && ws_region_parse(buf + 0x38, (uint32_t)osz, &rc, &nr, &bb) == 0 && bb.w > 0 && bb.h > 0) { ws_cursor_lock(srv, &bb); cursor_lock_owner = c->id; }
		else { ws_cursor_lock(srv, NULL); cursor_lock_owner = 0; }
		free(rc);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetCursorDragLock:                                                 /* 31 flag bytes @0x20, size 0x40: kept */
		if (!simple_ok(h, len, 0x40)) return reply_simple(c->fd, h, -304);
		memcpy(cursor_drag_lock, buf + 0x20, sizeof cursor_drag_lock);
		return reply_simple(c->fd, h, 0);
	case SLS_MSG_SetCursorRestrictionMode:                                          /* mode@0x20 (1..3 map to the system's modes, else 0), size 0x24 */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		cursor_restriction_mode = rd32(buf, 0x20) - 1u < 3 ? rd32(buf, 0x20) : 0;
		return reply_simple(c->fd, h, 0);
	case SLS_MSG_SetCursorRestrictionOptions:                                       /* corners byte@0x20, teleport byte@0x24, size 0x28 */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		cursor_restriction_corners = (uint8_t)rd32(buf, 0x20); cursor_teleport = (uint8_t)rd32(buf, 0x24);
		return reply_simple(c->fd, h, 0);
	case SLS_MSG_DisableCursorObscure:                                              /* double timeout@0x20 (clamped to 0.001 .. 0.5), size 0x28: the pointer is not hidden while typing until it expires (not modelled) */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0);
	case SLS_MSG_ForceWaitCursorActive:                                             /* flag@0x20, size 0x24 */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0);
	case SLS_MSG_SetWindowEventShape: {                                             /* OOL region; wid@0x34, size repeated@0x38; size 0x3c; applied with rights (type 2); always 0. The region is window-relative and decides where the window takes events */
		int err; int osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		uint32_t wid = rd32(buf, 0x34);
		if (ws_window_exists(srv, wid) && holds_rights(c, wid)) {
			ws_rect *rc = NULL; int nr = 0; ws_rect bb;
			if (osz && ws_region_parse(buf + 0x3c, (uint32_t)osz, &rc, &nr, &bb) == 0) ws_window_set_event_shape(srv, wid, rc, nr); else ws_window_set_event_shape(srv, wid, NULL, 0);
			free(rc);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowRegion: return do_set_property(c, buf, len);              /* the same request as SetWindowProperty (named, OOL bytes): the region is kept as a named window value */
	case SLS_MSG_DeleteWindowRegion: return do_delete_property(c, buf, len);        /* the same request as DeleteWindowProperty */
	case SLS_MSG_BlockWindowOrdering: {                                            /* value@0x20, size 0x24; reply value: 1 when the session's ordering counter (0 here) is below it */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		return reply_value(c->fd, h, (int32_t)rd32(buf, 0x20) > 0 ? 1 : 0);
	}
	case SLS_MSG_MoveWindowOnMatchingDisplayChangedSeed: {                         /* wid@0x20, x@0x24, y@0x28 (ints), display seed@0x2c, size 0x30: the window moves so that its origin becomes (x, y), with rights; 1000 for an unknown window or without rights
	                                                                                * (decompiled __XMoveWindowOnMatchingDisplayChangedSeed; the seed never changes here, so it always matches) */
		if (!simple_ok(h, len, 0x30)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (!wid || !ws_window_exists(srv, wid) || !holds_rights(c, wid)) return reply_simple(c->fd, h, 1000);
		ws_move_window(srv, wid, (int32_t)rd32(buf, 0x24), (int32_t)rd32(buf, 0x28));
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_OrderWindowListWithGroups: {                                      /* n@0x20, n ids, m, m operations, k, k relative windows; size 4(n+m+k) + 0x2c, each count <= 0x400; 1000 unless n == m == k > 0; an operation of 2 is
	                                                                                * turned into 1 with relative window 0 (decompiled __CGXOrderWindowListWithGroups); the windows of the group move together (ordering groups are not modelled) */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x2c || h->msgh_size > 0x302c) return reply_simple(c->fd, h, -304);
		uint32_t sz = h->msgh_size, n = rd32(buf, 0x20);
		if (n > 0x400 || 4 * n + 0x2c > sz) return reply_simple(c->fd, h, -304);
		uint32_t m = rd32(buf, 0x24 + 4 * n);
		if (m > 0x400 || sz - 4 * n < 4 * m + 0x2c) return reply_simple(c->fd, h, -304);
		uint32_t k = rd32(buf, 0x28 + 4 * n + 4 * m);
		if (k > 0x400 || sz != 4 * (n + m + k) + 0x2c) return reply_simple(c->fd, h, -304);
		if (n == 0 || n != m || n != k) return reply_simple(c->fd, h, 1000);
		for (uint32_t i = 0; i < n; i++) {
			uint32_t w = rd32(buf, 0x24 + 4 * i); int op = (int32_t)rd32(buf, 0x28 + 4 * n + 4 * i); uint32_t rel = rd32(buf, 0x2c + 4 * n + 4 * m + 4 * i);
			if (op == 2) { op = 1; rel = 0; }
			if (!w || !ws_window_exists(srv, w) || !holds_rights(c, w)) continue;
			ws_order_window(srv, w, op > 0 ? WS_ABOVE : op < 0 ? WS_BELOW : WS_OUT, rel);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_BringNextToFront:                                                 /* size 0x18; no process stack to rotate: 0 (decompiled __XBringNextToFront) */
		if (!simple_ok(h, len, 0x18)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0);
	case SLS_MSG_DoDeferredOrdering:                                               /* size 0x44; ordering is never deferred here: 0 */
		if (!simple_ok(h, len, 0x44)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0);
	case SLS_MSG_OrderWindowListWithOperation: {                                   /* n@0x20 (<= 0x400), n ids, then operation and relative window (u32 each); size 4n + 0x2c; 1000 for an empty list or a window without rights */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x2c || h->msgh_size > 0x102c) return reply_simple(c->fd, h, -304);
		uint32_t n = rd32(buf, 0x20);
		if (n > 0x400 || h->msgh_size != 4 * n + 0x2c) return reply_simple(c->fd, h, -304);
		if (n == 0) return reply_simple(c->fd, h, 1000);
		for (uint32_t i = 0; i < n; i++) { uint32_t w = rd32(buf, 0x24 + 4 * i); if (!w || !ws_window_exists(srv, w) || !holds_rights(c, w)) return reply_simple(c->fd, h, 1000); }
		int op = (int32_t)rd32(buf, 0x24 + 4 * n); uint32_t rel = rd32(buf, 0x28 + 4 * n);
		int mode = op > 0 ? WS_ABOVE : op < 0 ? WS_BELOW : WS_OUT;
		for (uint32_t i = 0; i < n; i++) ws_order_window(srv, rd32(buf, 0x24 + 4 * i), mode, rel);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowListSystemAlpha: {                                       /* n@0x20, n ids, m, m floats; size 4n + 4m + 0x28 (n, m <= 0x400); 0 */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x28 || h->msgh_size > 0x2028) return reply_simple(c->fd, h, -304);
		uint32_t n = rd32(buf, 0x20);
		if (n > 0x400 || h->msgh_size < 4 * n + 0x28) return reply_simple(c->fd, h, -304);
		uint32_t m = rd32(buf, 0x24 + 4 * n);
		if (m > 0x400 || h->msgh_size != 4 * n + 4 * m + 0x28) return reply_simple(c->fd, h, -304);
		for (uint32_t i = 0; i < n && i < m; i++) { uint32_t bits = rd32(buf, 0x28 + 4 * n + 4 * i); float a; memcpy(&a, &bits, 4); uint32_t w = rd32(buf, 0x24 + 4 * i); if (holds_rights(c, w)) ws_set_window_system_alpha(srv, w, a); }
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowListSystemLevel: {                                       /* class@0x20 (< 3), n@0x24 (<= 0x400), n ids; size 4n + 0x2c; 1001 for a bad class, 1000 for an empty list */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x2c || h->msgh_size > 0x102c) return reply_simple(c->fd, h, -304);
		uint32_t n = rd32(buf, 0x24);
		if (n > 0x400 || h->msgh_size != 4 * n + 0x2c) return reply_simple(c->fd, h, -304);
		if (rd32(buf, 0x20) >= 3) return reply_simple(c->fd, h, 0x3e9);
		if (n == 0) return reply_simple(c->fd, h, 1000);
		for (uint32_t i = 0; i < n; i++) ws_set_window_system_level(srv, rd32(buf, 0x28 + 4 * i), (int)rd32(buf, 0x20));
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_CopyWindowsWithOptionsAndTagsAndSpaceOptions: {                   /* two space option words @0x20/@0x24, options@0x28, tags u64@0x2c/@0x34; size 0x3c (no input descriptor). Reply as above: the ordered-in windows front to back */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size != 0x3c) return reply_simple(c->fd, h, -304);
		ws_wid ids[256]; int cnt = ws_list_windows(srv, 0, 1, ids, 256); if (cnt > 256) cnt = 256;
		uint32_t arr[256]; for (int i = 0; i < cnt; i++) arr[i] = ids[i];
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, (uint32_t)cnt * 4); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, (uint32_t)cnt);
		struct iovec v[2] = { { m, sizeof m }, { arr, (size_t)cnt * 4 } };
		return ws_ipc_send(c->fd, v, cnt ? 2 : 1, NULL, 0);
	}
	case SLS_MSG_CopyWindowsWithOptionsAndTags: {                                  /* OOL array of space ids (u64); options@0x34, u32@0x3c, tags u64@0x40, u64@0x48; size 0x50. Reply: OOL array of window ids (count@0x34), the ordered-in windows front to back (the filters are not applied) */
		int err; int osz = ool_request(h, buf, len, 0x50, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz / 8 != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		ws_wid ids[256]; int cnt = ws_list_windows(srv, 0, 1, ids, 256); if (cnt > 256) cnt = 256;
		uint32_t *arr = malloc((size_t)cnt * 4 + 4);
		if (!arr) return reply_simple(c->fd, h, 1000);
		for (int i = 0; i < cnt; i++) arr[i] = ids[i];
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, (uint32_t)cnt * 4); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, (uint32_t)cnt);
		struct iovec v[2] = { { m, sizeof m }, { arr, (size_t)cnt * 4 } };
		int rc = ws_ipc_send(c->fd, v, cnt ? 2 : 1, NULL, 0);
		free(arr);
		return rc;
	}
	case SLS_MSG_GetWindowRightHolder: {                                           /* wid@0x20, rights type@0x24 (1, 2 or 4), size 0x28; reply 0x28 with the holder's connection id; 1000 otherwise */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size != 0x28) return reply_simple(c->fd, h, -304);
		uint32_t t = rd32(buf, 0x24), wid = rd32(buf, 0x20);
		if (!ws_window_exists(srv, wid) || (t != 1 && t != 2 && t != 4)) return reply_simple(c->fd, h, 1000);
		uint8_t r[0x28]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
		wr32(r, 0x24, ws_window_owner(srv, wid));
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_GetWindowTransform: {                                             /* wid@0x20, entry@0x24 (0x7fffff00: the window's own transform), size 0x28; reply 0x40: flags@0x24, the 2D transform as six floats @0x28 (a b c d tx ty). No transform is ever set, so it is the identity (recorded on a macOS runner); 1000 for an unknown window */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size != 0x28) return reply_simple(c->fd, h, -304);
		if (!ws_window_exists(srv, rd32(buf, 0x20))) return reply_simple(c->fd, h, 1000);
		uint8_t r[0x40]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
		float one = 1.0f; memcpy(r + 0x28, &one, 4); memcpy(r + 0x34, &one, 4);          /* a = d = 1 */
		for (int i = 0; i < MAXXF; i++) if (xform[i].wid == rd32(buf, 0x20)) { memcpy(r + 0x28, xform[i].m, 24); break; }
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_GetWindowIsBuffered:                                              /* wid@0x20, size 0x24; reply 0x28 with a value at 0x24: a window without a backing surface reads 0 for the buffered flag (recorded), the main display depth 4 for the depth, 0 for has-alpha; 1000 for an unknown window (has-alpha: always 0) */
	case SLS_MSG_GetWindowDepth:
	case SLS_MSG_GetWindowHasAlpha: {
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size != 0x24) return reply_simple(c->fd, h, -304);
		if (h->msgh_id != SLS_MSG_GetWindowHasAlpha && !ws_window_exists(srv, rd32(buf, 0x20))) return reply_simple(c->fd, h, 1000);
		uint8_t r[0x28]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
		{ int ai = attr_slot(rd32(buf, 0x20), 0);
			if (h->msgh_id == SLS_MSG_GetWindowDepth) wr32(r, 0x24, ai >= 0 && attr[ai].depth ? (uint32_t)attr[ai].depth : 4);
			else if (h->msgh_id == SLS_MSG_GetWindowHasAlpha && ai >= 0 && attr[ai].have_alpha) r[0x24] = attr[ai].has_alpha; }
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_SetWindowDepth: {                                                 /* wid@0x20, depth@0x24, size 0x28; kept for the window; always 0 */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20); int ai;
		if (ws_window_exists(srv, wid) && holds_rights(c, wid) && (ai = attr_slot(wid, 1)) >= 0) attr[ai].depth = (int)rd32(buf, 0x24);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowIsOneShot:                                               /* wid@0x20, flag byte@0x24, size 0x28; rights needed; always 0 */
	case SLS_MSG_SetWindowHasAlpha:                                                /* the same, no rights check */
	case SLS_MSG_SetWindowClientPerceivedType: {                                   /* wid@0x20, type@0x24 */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20); int ai;
		if (ws_window_exists(srv, wid) && (h->msgh_id == SLS_MSG_SetWindowHasAlpha || holds_rights(c, wid) || h->msgh_id == SLS_MSG_SetWindowClientPerceivedType) && (ai = attr_slot(wid, 1)) >= 0) {
			if (h->msgh_id == SLS_MSG_SetWindowIsOneShot) attr[ai].oneshot = buf[0x24] != 0;
			else if (h->msgh_id == SLS_MSG_SetWindowHasAlpha) { attr[ai].has_alpha = buf[0x24] != 0; attr[ai].have_alpha = 1; }
			else attr[ai].perceived = (int)rd32(buf, 0x24);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowAutofillColor: {                                         /* wid@0x20, 12 bytes of colour@0x24, size 0x30; rights needed; always 0 */
		if (!simple_ok(h, len, 0x30)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20); int ai;
		if (ws_window_exists(srv, wid) && holds_rights(c, wid) && (ai = attr_slot(wid, 1)) >= 0) memcpy(attr[ai].autofill, buf + 0x24, 12);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetWindowTransform3D: {                                           /* wid@0x20, size 0x24; reply 0x64: the 4x4 matrix as 16 floats @0x24 (row major, m11 m12 .. m44); the 2D transform set by SetWindowTransform maps to a b / c d / tx ty; 1000 for an unknown window */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 1000);
		float m[16] = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 };
		for (int i = 0; i < MAXXF; i++) if (xform[i].wid == wid) { m[0] = xform[i].m[0]; m[1] = xform[i].m[1]; m[4] = xform[i].m[2]; m[5] = xform[i].m[3]; m[12] = xform[i].m[4]; m[13] = xform[i].m[5]; break; }
		uint8_t r[0x64]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, 8); memcpy(r + 0x24, m, sizeof m);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_MenuBarExists:                                                    /* size 0x18; reply 0x28: 1 (recorded) */
	case SLS_MSG_GetActiveMenuBarDrawingStyle:                                     /* reply 0x28: the style@0x24 */
	case SLS_MSG_GetMenuBarAutohideEnabled: {                                      /* reply 0x28: the flag byte@0x24 */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size != 0x18) return reply_simple(c->fd, h, -304);
		uint8_t r[0x28]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, 8);
		if (h->msgh_id == SLS_MSG_MenuBarExists) wr32(r, 0x24, 1); else if (h->msgh_id == SLS_MSG_GetActiveMenuBarDrawingStyle) wr32(r, 0x24, menubar_style); else r[0x24] = menubar_autohide;
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_SetSurfaceResolution: {                                           /* wid@0x20, surface@0x24, scale float@0x28, size 0x2c; kept for a surface of a known window written with rights; always 0 (decompiled __XSetSurfaceResolution) */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20), sid = rd32(buf, 0x24); float sc; memcpy(&sc, buf + 0x28, 4);
		if (ws_window_exists(srv, wid) && holds_rights(c, wid) && surface_of(wid, sid) && sc == sc) {
			int slot = -1; for (int i = 0; i < MAXSR; i++) { if (sres[i].wid == wid && sres[i].sid == sid) { slot = i; break; } if (slot < 0 && !sres[i].wid) slot = i; }
			if (slot >= 0) { sres[slot].wid = wid; sres[slot].sid = sid; sres[slot].scale = sc; }
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetSurfaceResolution: {                                           /* wid@0x20, surface@0x24, size 0x28; reply 0x30: scale float@0x24, pixel width / height ints @0x28 / @0x2c (the window size times the scale when the scale is above 1); 1000 for an unknown surface or a scale of 0 */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20), sid = rd32(buf, 0x24); ws_rect f; float sc = 1.0f;
		if (!ws_window_exists(srv, wid) || !surface_of(wid, sid) || ws_window_frame(srv, wid, &f)) return reply_simple(c->fd, h, 1000);
		for (int i = 0; i < MAXSR; i++) if (sres[i].wid == wid && sres[i].sid == sid) sc = sres[i].scale;
		if (sc == 0) return reply_simple(c->fd, h, 1000);
		double pw = f.w, ph = f.h; if (sc > 1.0f) { pw *= sc; ph *= sc; }
		uint8_t r[0x30]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR); memcpy(r + 0x24, &sc, 4); wr32(r, 0x28, (uint32_t)(int)pw); wr32(r, 0x2c, (uint32_t)(int)ph);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_PackagesSetWindowConstraints: {                                   /* wid@0x20, six doubles@0x24 (three size pairs), size 0x54; kept with rights on a known window; always 0 (decompiled __XPackagesSetWindowConstraints; a pair of zeros
	                                                                                * stands for the default, which is stored as given here) */
		if (!simple_ok(h, len, 0x54)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (ws_window_exists(srv, wid) && holds_rights(c, wid)) {
			int slot = -1; for (int i = 0; i < MAXWC; i++) { if (wcon[i].wid == wid) { slot = i; break; } if (slot < 0 && !wcon[i].wid) slot = i; }
			if (slot >= 0) { wcon[slot].wid = wid; memcpy(wcon[slot].v, buf + 0x24, 48); }
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_PackagesGetWindowConstraints: {                                   /* wid@0x20, size 0x24; reply 0x54: the six doubles@0x24, zeros when none were set or the caller has no rights */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		uint8_t r[0x54]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
		if (wid && ws_window_exists(srv, wid) && holds_rights(c, wid)) for (int i = 0; i < MAXWC; i++) if (wcon[i].wid == wid) memcpy(r + 0x24, wcon[i].v, 48);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_SetWindowColorProfile: {                                          /* wid@0x20, profile id@0x24, size 0x28; applied with rights to a known window, always 0 (decompiled __XSetWindowColorProfile) */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (ws_window_exists(srv, wid) && holds_rights(c, wid)) {
			int slot = -1; for (int i = 0; i < MAXCP; i++) { if (cprof[i].wid == wid) { slot = i; break; } if (slot < 0 && !cprof[i].wid) slot = i; }
			if (slot >= 0) { cprof[slot].wid = wid; cprof[slot].profile = rd32(buf, 0x24); }
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetWindowColorProfile: {                                          /* wid@0x20, size 0x24; reply 0x28: the profile id@0x24 (0 for an unknown window or none set) */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20), v = 0;
		for (int i = 0; i < MAXCP; i++) if (cprof[i].wid == wid && wid && ws_window_exists(srv, wid)) v = cprof[i].profile;
		return reply_value(c->fd, h, (int32_t)v);
	}
	case SLS_MSG_GetSystemWindow: {                                                /* kind@0x20, size 0x24; reply 0x28: the window id@0x24 (kind 4 = the menu bar window of the current space; none here, so 0); 1000 for another kind */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		if (rd32(buf, 0x20) != 4) return reply_simple(c->fd, h, 1000);
		return reply_value(c->fd, h, 0);
	}
	case SLS_MSG_SetMenuBarDrawingStyle:                                           /* style@0x20, size 0x24; always 0 */
	case SLS_MSG_SetMenuBarAutohideEnabled:                                        /* flag byte@0x20 */
	case SLS_MSG_SetMenuBarUseBlurredAppearance: {                                 /* flag byte@0x20 */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		if (h->msgh_id == SLS_MSG_SetMenuBarDrawingStyle) menubar_style = rd32(buf, 0x20); else if (h->msgh_id == SLS_MSG_SetMenuBarAutohideEnabled) menubar_autohide = buf[0x20] != 0; else menubar_blurred = buf[0x20] != 0;
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_ConnectionsForPid: {                                              /* pid@0x20, size 0x24; reply 4 * count + 0x28: count@0x24, connection ids from 0x28 */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t ids[64]; int pid = (int)rd32(buf, 0x20); uint32_t n = pid > 0 ? (uint32_t)wsd_conns_for_pid(pid, ids, 64) : 0;
		uint8_t r[0x28 + 64 * 4]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, 0x28 + 4 * n, 0);
		memcpy(r + 0x18, &WS_NDR, 8); wr32(r, 0x24, n); for (uint32_t i = 0; i < n; i++) wr32(r, 0x28 + 4 * i, ids[i]);
		return ws_ipc_send(c->fd, &(struct iovec){ r, 0x28 + 4 * n }, 1, NULL, 0);
	}
	case SLS_MSG_GetWindowList: {                                                  /* owner connection@0x20 (0: the whole session), capacity@0x24 (<= 0x400), size 0x28; reply 4 * count + 0x28: count@0x24, ids from 0x28 */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t cap = rd32(buf, 0x24); if (cap > 0x400) cap = 0x400;
		ws_wid ids[0x400]; int n = ws_list_windows(srv, rd32(buf, 0x20), 0, ids, (int)cap);
		if (n < 0) n = 0; if ((uint32_t)n > cap) n = (int)cap;
		uint8_t *r = calloc(1, 0x28 + 4 * (size_t)n); if (!r) return reply_simple(c->fd, h, 1000);
		fill_reply_header((mach_msg_header_t *)r, h, 0x28 + 4 * (uint32_t)n, 0);
		memcpy(r + 0x18, &WS_NDR, 8); wr32(r, 0x24, (uint32_t)n); for (int i = 0; i < n; i++) wr32(r, 0x28 + 4 * i, ids[i]);
		int rc2 = ws_ipc_send(c->fd, &(struct iovec){ r, 0x28 + 4 * (size_t)n }, 1, NULL, 0);
		free(r); return rc2;
	}
	case SLS_MSG_AreEventsCaptured: {                                              /* size 0x18; reply 0x2c: captured flag byte@0x24 and the mask of captured event types@0x28 (nothing is captured) */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size != 0x18) return reply_simple(c->fd, h, -304);
		uint8_t r[0x2c]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, 8);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_SetMouseEventEnableFlags: {                                       /* wid@0x20, flags@0x24, size 0x28; kept for a window the caller may change; always 0 */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (ws_window_exists(srv, wid) && holds_rights(c, wid)) {
			int slot = -1; for (int i = 0; i < 64; i++) { if (mouse_enable_wid[i] == wid) { slot = i; break; } if (slot < 0 && (!mouse_enable_wid[i] || !ws_window_exists(srv, mouse_enable_wid[i]))) slot = i; }
			if (slot >= 0) { mouse_enable_wid[slot] = wid; mouse_enable[slot] = rd32(buf, 0x24); }
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_ReenableCursorObscure: {                                          /* size 0x18; always 0 here (the obscure count is not nested) */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size != 0x18) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_NewCIFilter: {                                                    /* OOL plist string naming the filter; size repeated@0x34; size 0x38. Reply 0x28: the filter id@0x24; 1006 for a name that is not one of the two */
		int err; int osz = ool_request(h, buf, len, 0x38, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x34)) return reply_simple(c->fd, h, -300);
		char nm[64]; int type = 0;
		if (bp_string(buf + 0x38, (size_t)osz, nm, sizeof nm)) { if (!strcmp(nm, "CIShapedWaterRipple")) type = 1; else if (!strcmp(nm, "CIColorInvert")) type = 2; }
		if (!type) return reply_simple(c->fd, h, 0x3ee);
		int slot = -1; for (int i = 0; i < MAXCIF; i++) if (!cif[i].id) { slot = i; break; }
		if (slot < 0) return reply_simple(c->fd, h, 1000);
		cif[slot].id = next_cif++; cif[slot].owner = c->id; cif[slot].type = type; cif[slot].refs = 1;
		uint8_t r[0x28]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, 8); wr32(r, 0x24, cif[slot].id);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_ReleaseCIFilter: {                                                /* filter id@0x20, size 0x24; only the creating connection releases; always 0 */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		int i = cif_find(rd32(buf, 0x20));
		if (i >= 0 && cif[i].owner == c->id) { cif[i].owner = 0; if (cif[i].refs <= 1) memset(&cif[i], 0, sizeof cif[i]); else cif[i].refs--; }
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetCIFilterValues: {                                              /* OOL plist dict of input values; filter id@0x34, size repeated@0x38; size 0x3c; 1003 without a connection; always 0 otherwise */
		int err; int osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowCIFilter: {                                              /* wid@0x20, filter id@0x24, flags@0x28 (0: remove the window's filter; bit 8: drop the window's other filters first), size 0x2c; rights 4; always 0 */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20), fid = rd32(buf, 0x24), fl = rd32(buf, 0x28);
		if (ws_window_exists(srv, wid) && holds_rights(c, wid) && cif_find(fid) >= 0) {
			int slot = -1; for (int i = 0; i < 256; i++) { if (win_cif[i].wid == wid) { slot = i; break; } if (slot < 0 && (!win_cif[i].wid || !ws_window_exists(srv, win_cif[i].wid))) slot = i; }
			if (slot >= 0) { if (fl == 0) { if (win_cif[slot].fid == fid) { memset(&win_cif[slot], 0, sizeof win_cif[slot]); ws_set_window_filter(srv, wid, 0); } } else if ((fl & 0x100) || !win_cif[slot].fid || win_cif[slot].wid != wid) { win_cif[slot].wid = wid; win_cif[slot].fid = fid; ws_set_window_filter(srv, wid, cif[cif_find(fid)].type); } }
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetZoomParameters: {                                              /* size 0x18; reply 0x34: centre x y (integers)@0x24 (the screen centre when never set), scale float@0x2c, flag@0x30 */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size != 0x18) return reply_simple(c->fd, h, -304);
		uint8_t r[0x34]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, 8);
		wr32(r, 0x24, (uint32_t)(zoom_x == INT32_MIN ? wsd_screen_w / 2 : zoom_x)); wr32(r, 0x28, (uint32_t)(zoom_y == INT32_MIN ? wsd_screen_h / 2 : zoom_y));
		memcpy(r + 0x2c, &zoom_scale, 4); wr32(r, 0x30, zoom_flag);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_SetZoomParameters: {                                              /* centre x@0x20, y@0x24 (INT_MIN: keep), scale float@0x28, flag@0x2c, warp@0x30, float@0x34; size 0x38; scale clamped to 1..; always 0 */
		if (!simple_ok(h, len, 0x38)) return reply_simple(c->fd, h, -304);
		float sc; memcpy(&sc, buf + 0x28, 4);
		if (sc == sc && sc >= 1.0f) zoom_scale = sc > 64.0f ? 64.0f : sc; else zoom_scale = 1.0f;
		if ((int32_t)rd32(buf, 0x20) != INT32_MIN && (int32_t)rd32(buf, 0x24) != INT32_MIN) { zoom_x = (int32_t)rd32(buf, 0x20); zoom_y = (int32_t)rd32(buf, 0x24); }
		zoom_flag = rd32(buf, 0x2c) != 0;
		ws_server_set_zoom(srv, zoom_scale, zoom_x == INT32_MIN ? wsd_screen_w / 2 : zoom_x, zoom_y == INT32_MIN ? wsd_screen_h / 2 : zoom_y);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetWindowShmemReference: {                                        /* wid@0x20, size 0x24; reply complex 0x3c: one port descriptor (the window's memory entry; no descriptor is passed here), the return code overlays its pad word, NDR@0x28, then owner / rights / sharing state as GetWindowOwner reports them; 1000 for an unknown window */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size != 0x24) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 1000);
		uint8_t r[0x3c]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 1);
		wr32(r, 0x18, 1); wr32(r, 0x24, 0x110000u); memcpy(r + 0x28, &WS_NDR, sizeof WS_NDR);
		wr32(r, 0x30, ws_window_owner(srv, wid)); wr32(r, 0x34, holds_rights(c, wid) ? 0x30007u : 0); wr32(r, 0x38, 1);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_CopyAssociatedWindows: {                                          /* wid@0x20, size 0x24; reply complex 0x38: OOL array of the other windows of its ordering group, count@0x34; 1010 for an unknown window */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 0x3f2);
		ws_wid all[256]; int na = ws_window_ordering_group(srv, wid, all, 256); if (na > 256) na = 256;
		uint32_t arr[256]; uint32_t n = 0; for (int i = 0; i < na; i++) if (all[i] != wid) arr[n++] = all[i];
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, n * 4); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, n);
		struct iovec v[2] = { { m, sizeof m }, { arr, (size_t)n * 4 } };
		return ws_ipc_send(c->fd, v, n ? 2 : 1, NULL, 0);
	}
	case SLS_MSG_GetWindowMovementGroup:                                           /* wid@0x20, size 0x24; reply complex 0x38: OOL array of the group's window ids, the byte length in both the descriptor size and @0x34 (as decompiled); 1001 for an unknown window */
	case SLS_MSG_GetWindowOrderingGroup: {
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size != 0x24) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 0x3e9);
		ws_wid ids[256]; int n = h->msgh_id == SLS_MSG_GetWindowMovementGroup ? ws_window_movement_group(srv, wid, ids, 256) : ws_window_ordering_group(srv, wid, ids, 256);
		if (n > 256) n = 256;
		uint32_t arr[256]; for (int i = 0; i < n; i++) arr[i] = ids[i];
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, (uint32_t)n * 4); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, (uint32_t)n * 4);
		struct iovec v[2] = { { m, sizeof m }, { arr, (size_t)n * 4 } };
		return ws_ipc_send(c->fd, v, n ? 2 : 1, NULL, 0);
	}
	case SLS_MSG_AddWindowToWindowMovementGroup:                                   /* parent@0x20, child@0x24, size 0x28; rights on both; always 0 */
	case SLS_MSG_RemoveWindowFromWindowMovementGroup: {
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t p = rd32(buf, 0x20), ch = rd32(buf, 0x24);
		if (holds_rights(c, p) && holds_rights(c, ch)) {
			if (h->msgh_id == SLS_MSG_AddWindowToWindowMovementGroup) ws_window_set_movement_parent(srv, ch, p);
			else if (ws_window_movement_parent(srv, ch) == p) ws_window_set_movement_parent(srv, ch, 0);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_ClearWindowMovementGroup:                                         /* wid@0x20, size 0x24 */
	case SLS_MSG_ClearWindowOrderingGroup:
	case SLS_MSG_RemoveWindowFromWindowOrderingGroup: {
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (holds_rights(c, wid)) {
			if (h->msgh_id == SLS_MSG_ClearWindowMovementGroup) ws_window_clear_movement_group(srv, wid);
			else if (h->msgh_id == SLS_MSG_ClearWindowOrderingGroup) ws_window_clear_ordering_group(srv, wid);
			else ws_window_set_ordering_parent(srv, wid, 0, 0);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_AddWindowToWindowOrderingGroup: {                                 /* wid@0x20, relation@0x24 (1 above, -1 below), parent@0x28, size 0x2c */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20), par = rd32(buf, 0x28); int32_t rel = (int32_t)rd32(buf, 0x24);
		if (ws_window_exists(srv, wid) && ws_window_exists(srv, par) && holds_rights(c, wid) && holds_rights(c, par)) ws_window_set_ordering_parent(srv, wid, rel, par);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowLevelForGroup: {                                         /* wid@0x20, level@0x24, size 0x28: the window and its ordering group take the level */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20); int lv = (int)rd32(buf, 0x24);
		if (ws_window_exists(srv, wid) && holds_rights(c, wid)) {
			ws_wid ids[256]; int n = ws_window_ordering_group(srv, wid, ids, 256); if (n > 256) n = 256;
			ws_set_window_level(srv, wid, lv);
			for (int i = 0; i < n; i++) if (ids[i] != wid && holds_rights(c, ids[i])) ws_set_window_level(srv, ids[i], lv);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowOriginRelativeToWindow: {                                /* wid@0x20, relative window@0x24, dx / dy floats @0x28/@0x2c, flag@0x30, size 0x34: the origin becomes the other window's origin plus the offset; 1000 when a window is unknown or lacks rights */
		if (!simple_ok(h, len, 0x34)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20), rel = rd32(buf, 0x24); float dx, dy; memcpy(&dx, buf + 0x28, 4); memcpy(&dy, buf + 0x2c, 4);
		ws_rect rf;
		if (!ws_window_exists(srv, wid) || ws_window_frame(srv, rel, &rf) || !holds_rights(c, wid) || !holds_rights(c, rel)) return reply_simple(c->fd, h, 1000);
		{ double nx = rf.x + dx, ny = rf.y + dy; if (!(nx > -1e6 && nx < 1e6)) nx = 0; if (!(ny > -1e6 && ny < 1e6)) ny = 0;      /* NaN / huge offsets are clamped, never converted blindly */
			ws_move_window(srv, wid, (int)nx, (int)ny); }
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowHasKeyAppearance:                                        /* wid@0x20, flag@0x24, size 0x28: the window is drawn active (shadow, state) even when it is not the key window; applied with rights; always 0 */
	case SLS_MSG_SetWindowHasMainAppearance: {
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		if (ws_window_exists(srv, wid) && holds_rights(c, wid)) ws_window_set_appearance(srv, wid, h->msgh_id == SLS_MSG_SetWindowHasKeyAppearance ? 1 : 2, (rd32(buf, 0x24) & 0xff) != 0);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_AssociateMouseAndMouseCursorPosition: {                           /* flag byte@0x20 (1: the pointer follows the mouse, 0: it is held still and motion arrives as deltas), size 0x24; released when the connection goes; always 0 */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		ws_server_decouple(srv, c->id, (buf[0x20] & 1) == 0);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetCursorScale: {                                                 /* scale float@0x20 (taken when 0 < scale < 16), size 0x24; always 0. Kept; the cursor is drawn at its fixed size */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t bits = rd32(buf, 0x20); float f; memcpy(&f, &bits, 4);
		if (f > 0.0f && f < 16.0f) { cursor_scale = f; ws_set_cursor_scale(srv, f); }
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_WindowRightsRelinquish: {                                         /* wid@0x20, rights@0x24, size 0x28; 1001 for exclusive or unheld rights */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, wsd_rights_relinquish(c, rd32(buf, 0x20), rd32(buf, 0x24)));
	}
	case SLS_MSG_CompleteWindowRightsGrant: {                                      /* wid@0x20, grant id@0x24, size 0x2c; 1001 no grant, 1010 wrong recipient or id */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, wsd_grant_complete(c, rd32(buf, 0x20), rd32(buf, 0x24)));
	}
	case SLS_MSG_GrantConnectionRightsOnWindowReserving: {                        /* recipient connection@0x20, rights@0x24, window@0x28, reserved rights@0x2c, u64@0x30, length@0x3c, text; size pad4(length) + 0x40 */
		uint32_t n = h->msgh_size >= 0x40 ? rd32(buf, 0x3c) : 0;
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x40 || h->msgh_size > 0x440 || n > 0x400 || h->msgh_size != ((n + 3) & 0xffc) + 0x40) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, wsd_grant_create(c, rd32(buf, 0x20), rd32(buf, 0x28), rd32(buf, 0x24), rd32(buf, 0x2c)));
	}
	case SLS_MSG_SetWindowTransform: {                                             /* flags@0x20, entry@0x24, wid@0x28, a b c d tx ty floats @0x2c, size 0x44; kept per window, applied with rights; always 0 */
		if (!simple_ok(h, len, 0x44)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x28);
		if (ws_window_exists(srv, wid) && holds_rights(c, wid)) {
			int slot = -1; for (int i = 0; i < MAXXF; i++) { if (xform[i].wid == wid) { slot = i; break; } if (slot < 0 && !xform[i].wid) slot = i; }
			if (slot >= 0) { xform[slot].wid = wid; memcpy(xform[slot].m, buf + 0x2c, 24); }
			ws_set_window_transform(srv, wid, (const float *)(const void *)(buf + 0x2c));
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_WindowRoutingRecordsForScreenLocation: {                         /* x@0x20, y@0x24 (integers), size 0x28; reply complex 0x38: OOL bplist {"Routing Records": [{Location{X, Y}, "Context ID", "Connection ID"}], "WindowID"} for the window under the point (recorded layout: reals for the location, relative to the window) */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		int x = (int)rd32(buf, 0x20), y = (int)rd32(buf, 0x24);
		ws_wid hit = ws_find_window(srv, x, y); ws_rect f = { 0, 0, 0, 0 };
		if (hit) ws_window_frame(srv, hit, &f);
		bp_node kX = { BP_STR, "X", 0, 0, NULL, NULL, 0, -1 }, kY = { BP_STR, "Y", 0, 0, NULL, NULL, 0, -1 };
		bp_node vX = { BP_REAL, NULL, 0, (double)(x - f.x), NULL, NULL, 0, -1 }, vY = { BP_REAL, NULL, 0, (double)(y - f.y), NULL, NULL, 0, -1 };
		bp_node *lk[2] = { &kX, &kY }, *lv[2] = { &vX, &vY };
		bp_node loc = { BP_DICT, NULL, 0, 0, lv, lk, 2, -1 };
		bp_node kL = { BP_STR, "Location", 0, 0, NULL, NULL, 0, -1 }, kC = { BP_STR, "Context ID", 0, 0, NULL, NULL, 0, -1 }, kO = { BP_STR, "Connection ID", 0, 0, NULL, NULL, 0, -1 };
		bp_node vC = { BP_INT, NULL, 0, 0, NULL, NULL, 0, -1 }, vO = { BP_INT, NULL, hit ? ws_window_owner(srv, hit) : 0, 0, NULL, NULL, 0, -1 };
		bp_node *rk[3] = { &kL, &kC, &kO }, *rv[3] = { &loc, &vC, &vO };
		bp_node rec = { BP_DICT, NULL, 0, 0, rv, rk, 3, -1 };
		bp_node *ra[1] = { &rec };
		bp_node arr = { BP_ARRAY, NULL, 0, 0, ra, NULL, hit ? 1 : 0, -1 };
		bp_node kR = { BP_STR, "Routing Records", 0, 0, NULL, NULL, 0, -1 }, kW = { BP_STR, "WindowID", 0, 0, NULL, NULL, 0, -1 };
		bp_node vW = { BP_INT, NULL, hit, 0, NULL, NULL, 0, -1 };
		bp_node *tk[2] = { &kR, &kW }, *tv[2] = { &arr, &vW };
		bp_node top = { BP_DICT, NULL, 0, 0, tv, tk, 2, -1 };
		uint8_t *pl = NULL; size_t pn = bp_serialize(&top, &pl);
		if (!pl) return reply_simple(c->fd, h, 1000);
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, (uint32_t)pn); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, (uint32_t)pn);
		struct iovec v[2] = { { m, sizeof m }, { pl, pn } };
		int rc = ws_ipc_send(c->fd, v, 2, NULL, 0);
		free(pl);
		return rc;
	}
	case SLS_MSG_GetSpecifiedWindowShape: {                                        /* wid@0x20, kind@0x24, size 0x28; reply complex 0x38 with a serialized region; a window without a specified shape answers the empty region located at its origin (recorded: 0x80000000, 4, x, y, 0x7fffffff); 1000 for an unknown window */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		ws_rect f;
		if (ws_window_frame(srv, rd32(buf, 0x20), &f)) return reply_simple(c->fd, h, 1000);
		uint8_t reg[20]; wr32(reg, 0, 0x80000000u); wr32(reg, 4, 4); wr32(reg, 8, (uint32_t)(int)f.x); wr32(reg, 12, (uint32_t)(int)f.y); wr32(reg, 16, 0x7fffffffu);
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, sizeof reg); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, sizeof reg);
		struct iovec v[2] = { { m, sizeof m }, { reg, sizeof reg } };
		return ws_ipc_send(c->fd, v, 2, NULL, 0);
	}
	case SLS_MSG_SetWindowParent: {                                                /* child@0x20, parent@0x24, size 0x28; rights on both; always 0 */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t child = rd32(buf, 0x20), parent = rd32(buf, 0x24);
		if (child && parent && ws_window_exists(srv, child) && ws_window_exists(srv, parent) && holds_rights(c, child) && holds_rights(c, parent)) ws_window_set_parent(srv, child, parent);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetParentWindowList: {                                            /* n@0x20 (must be 0x400, else 1001), n window ids; size 4n + 0x24. Reply 0x1028: retcode, 0x400@0x24, the parent of each id (0: none or invalid window) at 0x28 */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x24 || h->msgh_size > 0x1024) return reply_simple(c->fd, h, -304);
		uint32_t n = rd32(buf, 0x20);
		if (n > 0x400 || h->msgh_size != 4 * n + 0x24) return reply_simple(c->fd, h, -304);
		if (n != 0x400) return reply_simple(c->fd, h, 1001);                      /* recorded on a macOS runner (and in the decompile): only a full list of 0x400 ids is accepted */
		uint8_t *r = calloc(1, 0x1028);
		if (!r) return reply_simple(c->fd, h, 1000);
		fill_reply_header((mach_msg_header_t *)r, h, 0x1028, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
		wr32(r, 0x24, 0x400);
		for (uint32_t i = 0; i < n; i++) wr32(r, 0x28 + 4 * i, ws_window_parent(srv, rd32(buf, 0x24 + 4 * i)));
		int rc = ws_ipc_send(c->fd, &(struct iovec){ r, 0x1028 }, 1, NULL, 0);
		free(r);
		return rc;
	}
	case SLS_MSG_WindowIsVisible: {                                                /* wid@0x20, size 0x24; reply 0x28 with the byte at 0x24: 1 when ordered in; 0 for an unknown window */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint8_t r[0x28]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
		r[0x24] = ws_window_exists(srv, rd32(buf, 0x20)) && ws_window_on_screen(srv, rd32(buf, 0x20)) ? 1 : 0;
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_SetWindowTransformList: {                                         /* 2 OOL: window ids (u32 each), transforms (24 bytes each: a b c d tx ty); NDR@0x3c, flags@0x44, entry@0x48, counts@0x4c / 0x50 (must match the sizes); size 0x54 */
		size_t off[2]; uint32_t sz[2]; int e = ool_multi(h, buf, len, 0x54, 2, off, sz);
		if (e) return reply_simple(c->fd, h, e);
		if ((sz[0] >> 2) != rd32(buf, 0x4c) || sz[1] / 0x18 != rd32(buf, 0x50)) return reply_simple(c->fd, h, -300);
		uint32_t n = sz[0] >> 2; if (sz[1] / 0x18 < n) n = sz[1] / 0x18;                  /* applied pairwise */
		for (uint32_t i = 0; i < n; i++) {
			uint32_t wid = rd32(buf, off[0] + 4 * i);
			if (ws_window_exists(srv, wid) && holds_rights(c, wid)) ws_set_window_transform(srv, wid, (const float *)(const void *)(buf + off[1] + 0x18 * i));
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowListBrightness: {                                        /* 2 OOL: window ids (u32 each), brightness (float each); counts@0x44 / 0x48 (must match the sizes, decompiled __XSetWindowListBrightness); size 0x4c; applied pairwise */
		size_t off[2]; uint32_t sz[2]; int e = ool_multi(h, buf, len, 0x4c, 2, off, sz);
		if (e) return reply_simple(c->fd, h, e);
		if ((sz[0] >> 2) != rd32(buf, 0x44) || (sz[1] >> 2) != rd32(buf, 0x48)) return reply_simple(c->fd, h, -300);
		uint32_t n = sz[0] >> 2; if ((sz[1] >> 2) < n) n = sz[1] >> 2;
		for (uint32_t i = 0; i < n; i++) {
			uint32_t wid = rd32(buf, off[0] + 4 * i); float b; memcpy(&b, buf + off[1] + 4 * i, 4);
			if (ws_window_exists(srv, wid) && holds_rights(c, wid)) ws_set_window_brightness(srv, wid, b);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowCornerMask: {                                             /* 1 OOL (the mask, one byte per pixel), size 0x68, wid@0x34, the OOL size again@0x38, width@0x3c, height@0x40, format@0x44, four doubles@0x48 (the stretch rectangle, 0..1; both pairs infinite = the default); decompiled __XSetWindowCornerMask: -304 / -300 for a bad message / OOL, nothing happens without rights or when width * height overflows 32 bits or exceeds the data;
		 * the mask is a small picture of the window's corner stretched over its shape: kept here as the corner radius (the pixels of the first row that are less than half covered) */
		size_t off[1]; uint32_t sz[1]; int e = ool_multi(h, buf, len, 0x68, 1, off, sz);
		if (e) return reply_simple(c->fd, h, e);
		if (sz[0] != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		uint32_t wid = rd32(buf, 0x34), mw = rd32(buf, 0x3c), mh = rd32(buf, 0x40);
		if (!ws_window_exists(srv, wid) || !holds_rights(c, wid)) return reply_simple(c->fd, h, 0);
		uint64_t px = (uint64_t)mw * mh;
		if (px >> 32 || !px || px > sz[0]) { ws_set_window_corner_radius(srv, wid, 0); return reply_simple(c->fd, h, 0); }
		uint32_t r = 0; while (r < mw && buf[off[0] + r] < 128) r++;
		ws_set_window_corner_radius(srv, wid, (int)(r > mw / 2 ? mw / 2 : r));
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowListFadeProperties: {                                     /* 1 OOL (window ids), count@0x34 (<= 0x400), then count u32 properties inline from 0x38 and the OOL size repeated after them: size 0x3c + 4 * count; decompiled __XSetWindowListFadeProperties (-304 bad message, -300 bad descriptor / size mismatch); applied pairwise, kept per window (read back through the window's properties) */
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len < 0x3c || rd32(buf, 0x18) != 1 || buf[0x27] != 1) return reply_simple(c->fd, h, buf[0x27] != 1 && len >= 0x28 && (h->msgh_bits & MACH_MSGH_BITS_COMPLEX) ? -300 : -304);
		uint32_t n = rd32(buf, 0x34), osz = rd32(buf, 0x28);
		if (n > 0x400 || h->msgh_size != n * 4 + 0x3c || len < (size_t)h->msgh_size + osz) return reply_simple(c->fd, h, -304);
		if (osz != rd32(buf, 0x38 + n * 4)) return reply_simple(c->fd, h, -300);
		for (uint32_t i = 0; i < n && 4 * (i + 1) <= osz; i++) {
			uint32_t wid = rd32(buf, h->msgh_size + 4 * i);
			if (ws_window_exists(srv, wid) && holds_rights(c, wid)) ws_set_window_fade_property(srv, wid, rd32(buf, 0x38 + 4 * i));
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowListGlobalClipShape:
	case SLS_MSG_RemoveWindowListGlobalClipShape: {                                /* Set: 1 OOL (the region), OOL size@0x28 repeated@0x34, count@0x38 (<= 0x400), ids inline from 0x3c, size 0x3c + 4 * count (decompiled __XSetWindowListGlobalClipShape; -304 / -300; the reply code is the routine's result, 0).
		 * Remove (decompiled __XRemoveWindowListGlobalClipShape): not complex, count@0x20 (<= 0x400), ids inline from 0x24, size 0x24 + 4 * count; 1000 when a window is unknown or not ours */
		int rem = h->msgh_id == SLS_MSG_RemoveWindowListGlobalClipShape;
		if (rem) {
			if (len < 0x24) return reply_simple(c->fd, h, -304);
			uint32_t n = rd32(buf, 0x20); if (n > 0x400 || h->msgh_size != n * 4 + 0x24 || len < h->msgh_size) return reply_simple(c->fd, h, -304);
			if (h->msgh_bits & MACH_MSGH_BITS_COMPLEX) return reply_simple(c->fd, h, -304);
			for (uint32_t i = 0; i < n; i++) { uint32_t wid = rd32(buf, 0x24 + 4 * i); if (!wid || !ws_window_exists(srv, wid) || !holds_rights(c, wid)) return reply_simple(c->fd, h, 1000); }      /* every window must exist and be ours before anything changes */
			for (uint32_t i = 0; i < n; i++) ws_set_window_global_clip(srv, rd32(buf, 0x24 + 4 * i), NULL, 0);
			return reply_simple(c->fd, h, 0);
		}
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len < 0x3c || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
		if (buf[0x27] != 1) return reply_simple(c->fd, h, -300);
		uint32_t osz = rd32(buf, 0x28), n = rd32(buf, 0x38);
		if (n > 0x400 || h->msgh_size != n * 4 + 0x3c || len < (size_t)h->msgh_size + osz) return reply_simple(c->fd, h, -304);
		if (osz != rd32(buf, 0x34)) return reply_simple(c->fd, h, -300);
		ws_rect *rc = NULL; int nr = 0; ws_rect bb;
		if (osz && ws_region_parse(buf + h->msgh_size, osz, &rc, &nr, &bb)) { nr = 0; rc = NULL; }
		for (uint32_t i = 0; i < n; i++) { uint32_t wid = rd32(buf, 0x3c + 4 * i); if (ws_window_exists(srv, wid) && holds_rights(c, wid)) ws_set_window_global_clip(srv, wid, rc, nr); }
		free(rc); return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_AddTrackingAreas: {                                               /* 5 OOL, size 0x8c, wid@0x74; the descriptor sizes must agree with the counts@0x78..0x88. Inferred layout (not decompiled below the wire checks): region bytes of all areas, the byte length of each area's region (u32), the area ids (u64), flags, user data (u64) */
		size_t off[5]; uint32_t sz[5]; int e = ool_multi(h, buf, len, 0x8c, 5, off, sz);
		if (e) return reply_simple(c->fd, h, e);
		if (sz[0] != rd32(buf, 0x78) || (sz[1] >> 2) != rd32(buf, 0x7c) || (sz[2] >> 3) != rd32(buf, 0x80) || sz[3] != rd32(buf, 0x84) || (sz[4] >> 3) != rd32(buf, 0x88)) return reply_simple(c->fd, h, -300);
		uint32_t wid = rd32(buf, 0x74), n = sz[2] >> 3, used = 0;
		if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 1000);
		if (!holds_rights(c, wid)) return reply_simple(c->fd, h, 0);
		for (uint32_t i = 0; i < n && i < (sz[1] >> 2); i++) {
			uint32_t rl = rd32(buf, off[1] + 4 * i); uint64_t id; memcpy(&id, buf + off[2] + 8 * i, 8);
			if (rl > sz[0] - used) break;
			ws_rect *rc = NULL; int nr = 0; ws_rect bb;
			if (rl && ws_region_parse(buf + off[0] + used, rl, &rc, &nr, &bb) == 0) ws_tracking_set(srv, id, wid, rc, nr); else ws_tracking_set(srv, id, wid, NULL, 0);
			free(rc); used += rl;
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowWarp: {                                                  /* OOL floats; wid@0x34, columns@0x38 and rows@0x3c (each <= 0x800), float count@0x40 (4 per point: columns * rows * 4), size 0x44; every float below 2^31; 1000 for a bad mesh (decompiled __XSetWindowWarp, CGXWindow::set_mesh_warp) */
		int err; int osz = ool_request(h, buf, len, 0x44, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		uint32_t nf = (uint32_t)osz >> 2, wid = rd32(buf, 0x34), cols = rd32(buf, 0x38), rows = rd32(buf, 0x3c);
		if (nf != rd32(buf, 0x40)) return reply_simple(c->fd, h, -300);
		if (cols > 0x800 || rows > 0x800 || nf != cols * rows * 4) return reply_simple(c->fd, h, 1000);
		const uint8_t *fl = buf + 0x44;
		for (uint32_t i = 0; i < nf; i++) { float f; memcpy(&f, fl + 4 * i, 4); if (!(fabsf(f) < 2.1474836e+09f)) return reply_simple(c->fd, h, 1000); }
		if (ws_window_exists(srv, wid) && holds_rights(c, wid)) ws_set_window_warp(srv, wid, (int)cols, (int)rows, nf ? (const float *)(const void *)fl : NULL);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowCaptureExcludeShape: {                                   /* OOL region; wid@0x34, size repeated@0x38, size 0x3c; needs write access, an empty region does nothing; 0 (decompiled __XSetWindowCaptureExcludeShape) */
		int err; int osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		uint32_t wid = rd32(buf, 0x34);
		if (osz && ws_window_exists(srv, wid) && holds_rights(c, wid)) {
			ws_rect *rc = NULL; int nr = 0; ws_rect bb;
			if (ws_region_parse(buf + 0x3c, (uint32_t)osz, &rc, &nr, &bb) == 0) ws_set_window_capture_exclude(srv, wid, rc, nr);
			free(rc);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_AddTrackingArea: {                                                /* OOL region; wid@0x34, size repeated@0x38, compat id u64@0x3c, u64@0x48 (user data); size 0x50; 0 */
		int err; int osz = ool_request(h, buf, len, 0x50, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		uint32_t wid = rd32(buf, 0x34); uint64_t id; memcpy(&id, buf + 0x3c, 8);
		if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 1000);        /* recorded on a macOS runner */
		{
			ws_rect *rc = NULL; int nr = 0; ws_rect bb;
			if (osz && ws_region_parse(buf + 0x50, (uint32_t)osz, &rc, &nr, &bb) == 0) ws_tracking_set(srv, id, wid, rc, nr);
			else ws_tracking_set(srv, id, wid, NULL, 0);
			free(rc);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_MoveTrackingArea: {                                               /* wid@0x20, compat id u64@0x24, x@0x2c, y@0x30, size 0x34; 1000 unknown window, 1001 unknown area, else 0 (applied with rights) */
		if (!simple_ok(h, len, 0x34)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20); uint64_t id; memcpy(&id, buf + 0x24, 8);
		if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 1000);
		if (!holds_rights(c, wid)) return reply_simple(c->fd, h, 1001);
		return reply_simple(c->fd, h, ws_tracking_move(srv, id, wid, (int)rd32(buf, 0x2c), (int)rd32(buf, 0x30)) ? 0x3e9 : 0);
	}
	case SLS_MSG_SetTrackingAreaEnabled: {                                        /* wid@0x20, compat id u64@0x24, enabled@0x2c, size 0x30; always 0 */
		if (!simple_ok(h, len, 0x30)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x24, 8);
		if (ws_window_exists(srv, rd32(buf, 0x20)) && holds_rights(c, rd32(buf, 0x20))) ws_tracking_set_enabled(srv, id, rd32(buf, 0x20), rd32(buf, 0x2c) != 0);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_RemoveTrackingArea: {                                             /* wid@0x20, compat id u64@0x24, size 0x2c; always 0 */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x24, 8);
		if (ws_window_exists(srv, rd32(buf, 0x20)) && holds_rights(c, rd32(buf, 0x20))) ws_tracking_remove(srv, id);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_RemoveAllTrackingAreas: {                                         /* wid@0x20, size 0x24; always 0 */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		if (ws_window_exists(srv, rd32(buf, 0x20)) && holds_rights(c, rd32(buf, 0x20))) ws_tracking_remove_window(srv, rd32(buf, 0x20));
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_RemoveTrackingAreas:
	case SLS_MSG_SetTrackingAreasEnabled: {                                        /* OOL array of compat ids (u64); wid@0x34, count@0x38 (= size / 8); size 0x3c (Remove) / 0x40 (SetEnabled, enabled flags after the count) */
		int remove = h->msgh_id == SLS_MSG_RemoveTrackingAreas;
		int err; int osz = ool_request(h, buf, len, remove ? 0x3c : 0x40, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz / 8 != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		uint32_t wid = rd32(buf, 0x34);
		if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 1000);
		if (!holds_rights(c, wid)) return reply_simple(c->fd, h, 1002);
		if (osz < 8) return reply_simple(c->fd, h, 0x3e9);                          /* "Null tracking area array" */
		const uint8_t *ids = buf + (remove ? 0x3c : 0x40);
		for (int i = 0; i < osz / 8; i++) { uint64_t id; memcpy(&id, ids + 8 * i, 8); if (remove) ws_tracking_remove(srv, id); else ws_tracking_set_enabled(srv, id, wid, rd32(buf, 0x3c) != 0); }      /* the enabled flag at 0x3c is inferred (unverified live) */
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_FlushRegion: {                                                    /* OOL region; wid@0x34, size repeated@0x38; size 0x3c: the region's bounds are flushed (an empty region: the whole window); always 0 */
		int err; int osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		uint32_t wid = rd32(buf, 0x34);
		if (ws_window_exists(srv, wid)) {
			ws_rect *rc = NULL; int nr = 0; ws_rect bb;
			if (osz && ws_region_parse(buf + 0x3c, (uint32_t)osz, &rc, &nr, &bb) == 0 && bb.w > 0 && bb.h > 0) ws_window_flush_rect(srv, wid, &bb); else ws_window_flush_rect(srv, wid, NULL);
			free(rc);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowClipShape: {                                             /* OOL region; wid@0x34, size repeated@0x38; size 0x3c: applied only with rights (not modelled), always 0 */
		int err; int osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_ShapeSurface: {                                                   /* OOL region; six u32 @0x34..0x48 (connection, window, surface, ...), size repeated@0x4c; size 0x50: accepted, not modelled */
		int err; int osz = ool_request(h, buf, len, 0x50, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x4c)) return reply_simple(c->fd, h, -300);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetTrackingAreaShape: {                                           /* OOL region; wid@0x34, compat id u64@0x38, region size repeated@0x40; size 0x48; 1000 for an unknown window or without rights */
		int err; int osz = ool_request(h, buf, len, 0x48, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x40)) return reply_simple(c->fd, h, -300);
		uint32_t wid = rd32(buf, 0x34); uint64_t id; memcpy(&id, buf + 0x38, 8);
		if (!ws_window_exists(srv, wid) || !holds_rights(c, wid)) return reply_simple(c->fd, h, 1000);
		ws_rect *rc = NULL; int nr = 0; ws_rect bb;
		if (osz && ws_region_parse(buf + 0x48, (uint32_t)osz, &rc, &nr, &bb) == 0) ws_tracking_set_shape(srv, id, rc, nr);
		free(rc);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_WindowSetShadowProperties: {                                     /* OOL serialized property list; wid@0x34, size repeated@0x38; size 0x3c. 1000 for an unknown window, else 0 (applied only with rights; kept opaque here) */
		int err; int osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		return reply_simple(c->fd, h, ws_window_exists(srv, rd32(buf, 0x34)) ? 0 : 1000);
	}
	case SLS_MSG_SetEventCapture:                                                  /* three u32 @0x20..0x28, size 0x2c: always answered 0 here (no event capture state yet) */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0);
	case SLS_MSG_SetWindowIsBuffered:                                              /* wid@0x20, flag byte@0x24, size 0x28: windows here are always buffered */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, ws_window_exists(srv, rd32(buf, 0x20)) && holds_rights(c, rd32(buf, 0x20)) ? 0 : 1000);
	case SLS_MSG_RemoveStructuralRegion: {                                         /* id u64@0x20, size 0x28, always 0 */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint64_t id; memcpy(&id, buf + 0x20, 8);
		ws_tracking_remove(srv, id);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_StructuralRegionSetShape: {                                       /* OOL region, id u64@0x34, size repeated@0x3c, size 0x40 */
		int err; int osz = ool_request(h, buf, len, 0x40, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x3c)) return reply_simple(c->fd, h, -300);
		uint64_t id; memcpy(&id, buf + 0x34, 8);
		ws_rect *rc = NULL; int nr = 0; ws_rect bb;
		if (osz && ws_region_parse(buf + 0x40, (uint32_t)osz, &rc, &nr, &bb) == 0) ws_tracking_set_shape(srv, id, rc, nr);
		free(rc);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_CopySpacesForWindows: {                                           /* OOL array of window ids (count@0x38 = size/4); reply OOL array of space ids (u64) */
		int err; int osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if (rd32(buf, 0x38) != (uint32_t)osz / 4) return reply_simple(c->fd, h, -300);
		uint32_t count = (uint32_t)osz / 4;
		uint64_t *spaces = malloc(count * 8 + 8);
		if (!spaces) return reply_simple(c->fd, h, 1000);
		for (uint32_t i = 0; i < count; i++) spaces[i] = sls_space_of_window(rd32(buf, 0x3c + 4 * i));   /* the space each window was put in (the default one otherwise) */
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, count * 8); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, count);
		struct iovec v[2] = { { m, sizeof m }, { spaces, count * 8 } };
		int rc = ws_ipc_send(c->fd, v, count ? 2 : 1, NULL, 0);
		free(spaces);
		return rc;
	}
	case SLS_MSG_SetWindowProperty: return do_set_property(c, buf, len);
	case SLS_MSG_GetWindowProperty: return do_get_property(c, buf, len);
	case SLS_MSG_DeleteWindowProperty: return do_delete_property(c, buf, len);
	case SLS_MSG_SetWindowLayerContext: {                                          /* wid@0x20, CA context id@0x24: 1002 without rights, else 0 */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20), ctx = rd32(buf, 0x24);
		if (!holds_rights(c, wid)) return reply_simple(c->fd, h, 1002);
		int slot = -1;
		for (int i = 0; i < 256; i++) if (layer_ctx[i].used && layer_ctx[i].wid == wid) slot = i;
		for (int i = 0; i < 256 && slot < 0; i++) if (!layer_ctx[i].used) slot = i;
		if (slot >= 0) { layer_ctx[slot].used = 1; layer_ctx[slot].wid = wid; layer_ctx[slot].ctx = ctx; }
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_WindowIsOrderedIn: {                                              /* byte@0x24: ordered in; 0 for a window it cannot see */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		uint32_t wid = rd32(buf, 0x20);
		return reply_value(c->fd, h, ws_window_on_screen(srv, wid) ? 1 : 0);
	}
	}
	return -2;
}

uint32_t cursor_lock_owner;
void sls_window_owner_cleanup(uint32_t owner) { ws_server_decouple(srv, owner, 0); if (cursor_lock_owner == owner) { cursor_lock_owner = 0; ws_cursor_lock(srv, NULL); } purge_dead(); for (int i = 0; i < MAXSHAPES; i++) if (shapes[i].wid && !ws_window_exists(srv, shapes[i].wid)) shape_store(shapes[i].kind, shapes[i].wid, NULL, 0); }
