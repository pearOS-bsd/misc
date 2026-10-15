/* Window routines beyond the core set in wsd.c: properties, layer context binding, ordered-in query. */
#include "wsd_priv.h"
#include "ws_region.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* window properties: name -> serialized property list bytes (kept opaque) */
#define MAXPROPS 512
static struct { int used; uint32_t wid; char key[130]; uint8_t *data; uint32_t len; } props[MAXPROPS];
static struct { int used; uint32_t wid, ctx; } layer_ctx[256];

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

/* complex requests with one OOL descriptor (count@0x18 = 1, type byte@0x27 = 1, size@0x28), NDR@0x2c; returns the checked descriptor size or -1 with *err set */
int ool_request(const mach_msg_header_t *h, const uint8_t *buf, size_t len, uint32_t want_size, int *err)
{
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != want_size || len < want_size || rd32(buf, 0x18) != 1) { *err = -304; return -1; }
	uint32_t osz = rd32(buf, 0x28);
	if (buf[0x27] != 1) { *err = -300; return -1; }
	if (len != (size_t)want_size + osz) { *err = -304; return -1; }
	return (int)osz;
}

extern uint32_t cursor_lock_owner;
static uint8_t cursor_drag_lock[31]; static uint32_t cursor_restriction_mode; static uint8_t cursor_restriction_corners, cursor_teleport;

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
			if (ws_region_parse(buf + 0x58, s1, &r, &nr, &bb) == 0 && bb.w > 0 && bb.h > 0) ws_set_window_frame(srv, wid, bb.x, bb.y, bb.w, bb.h);   /* the shape is in screen coordinates: its bounds are the new frame (verified live) */
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
	case SLS_MSG_GetWindowShape: {                                                 /* wid@0x20; reply complex 0x38 with the serialized shape; 1000 for an unknown window */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		ws_rect f;
		if (ws_window_frame(srv, rd32(buf, 0x20), &f)) return reply_simple(c->fd, h, 1000);
		ws_rect r = { 0, 0, f.w, f.h }; uint8_t reg[256];
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
	case SLS_MSG_AddTrackingArea: {                                                /* OOL region; wid@0x34, size repeated@0x38, compat id u64@0x3c, u64@0x48 (user data); size 0x50; 0 */
		int err; int osz = ool_request(h, buf, len, 0x50, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		uint32_t wid = rd32(buf, 0x34); uint64_t id; memcpy(&id, buf + 0x3c, 8);
		if (ws_window_exists(srv, wid)) {
			ws_rect *rc = NULL; int nr = 0; ws_rect bb;
			if (osz && ws_region_parse(buf + 0x50, (uint32_t)osz, &rc, &nr, &bb) == 0) ws_tracking_set(srv, id, wid, rc, nr);
			else ws_tracking_set(srv, id, wid, NULL, 0);
			free(rc);
		}
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
void sls_window_owner_cleanup(uint32_t owner) { if (cursor_lock_owner == owner) { cursor_lock_owner = 0; ws_cursor_lock(srv, NULL); } purge_dead(); }
