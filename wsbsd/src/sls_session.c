/* Connection / session / process level routines: version, session ports, client dictionaries, debug options, appearance. */
#include "wsd_priv.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

int sls_golden_reply(conn *c, const mach_msg_header_t *h);

/* CreateApplication (30283): the process record a connection needs for key focus and the process calls. Request: PSN@0x20 (hi, lo), session id@0x28,
 * pid@0x2c, application type@0x30 (1..4), euid@0x34, name offset@0x38, name length@0x3c (<= 0x80), name@0x40, then flag byte, two u32. Size = pad4(len) + 0x4c.
 * Unverified live: which argument combinations the real server accepts (a zero session id gives -50 there). */
static int do_create_application(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x4c || h->msgh_size > 0xcc) return reply_simple(c->fd, h, -304);
	uint32_t n = rd32(buf, 0x3c), P = (n + 3) & ~3u;
	if (n > 0x80 || h->msgh_size != P + 0x4c) return reply_simple(c->fd, h, -304);
	uint32_t sid = rd32(buf, 0x28), pid = rd32(buf, 0x2c), type = rd32(buf, 0x30);
	uint8_t flag = buf[0x40 + P];
	if (type < 1 || type > 4 || n == 0 || buf[0x40] == 0 || (pid < 2 && flag != 1)) return reply_simple(c->fd, h, -50);
	if (!sid) return reply_simple(c->fd, h, -50);                                   /* "App checking in with invalid session id" */
	if (c->registered) return reply_simple(c->fd, h, -50);
	c->registered = 1; c->psn_hi = rd32(buf, 0x20); c->psn_lo = rd32(buf, 0x24); c->session_id = sid; c->app_type = (int)type;
	snprintf(c->app, sizeof c->app, "%.*s", (int)(n < 63 ? n : 63), (const char *)buf + 0x40);
	return reply_simple(c->fd, h, 0);
}

/* connection properties (30181/30182), the same shape as window properties with a connection id in place of the window id */
static struct { int used; uint32_t cid; char key[130]; uint8_t *data; uint32_t len; } cprops[128];

static int do_set_conn_property(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len < 0x44 || h->msgh_size < 0x44 || h->msgh_size > 0xc4 || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
	if (buf[0x27] != 1) return reply_simple(c->fd, h, -300);
	uint32_t osz = rd32(buf, 0x28), n = rd32(buf, 0x3c), P = (n + 3) & ~3u;
	if (n > 0x80 || h->msgh_size != P + 0x44 || len != (size_t)h->msgh_size + osz) return reply_simple(c->fd, h, -304);
	if (rd32(buf, 0x40 + P) != osz) return reply_simple(c->fd, h, -300);
	char key[130]; memcpy(key, buf + 0x40, n); key[n] = 0; key[strnlen(key, n)] = 0;
	uint32_t cid = rd32(buf, 0x34);
	int slot = -1;
	for (int i = 0; i < 128; i++) if (cprops[i].used && cprops[i].cid == cid && !strcmp(cprops[i].key, key)) { slot = i; free(cprops[i].data); cprops[i].data = NULL; }
	for (int i = 0; i < 128 && slot < 0; i++) if (!cprops[i].used) slot = i;
	if (slot < 0) return reply_simple(c->fd, h, 1000);
	uint8_t *d = osz ? malloc(osz) : NULL;
	if (osz && !d) return reply_simple(c->fd, h, 1000);
	if (osz) memcpy(d, buf + h->msgh_size, osz);
	cprops[slot].used = 1; cprops[slot].cid = cid; snprintf(cprops[slot].key, sizeof cprops[slot].key, "%s", key); cprops[slot].data = d; cprops[slot].len = osz;
	return reply_simple(c->fd, h, 0);
}

static int do_get_conn_property(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x2c || h->msgh_size > 0xac) return reply_simple(c->fd, h, -304);
	uint32_t n = rd32(buf, 0x28), cid = rd32(buf, 0x20);
	if (n > 0x80 || h->msgh_size != ((n + 3) & ~3u) + 0x2c) return reply_simple(c->fd, h, -304);
	char key[130]; memcpy(key, buf + 0x2c, n); key[n] = 0; key[strnlen(key, n)] = 0;
	const uint8_t *data = NULL; uint32_t dl = 0;
	for (int i = 0; i < 128; i++) if (cprops[i].used && cprops[i].cid == cid && !strcmp(cprops[i].key, key)) { data = cprops[i].data; dl = cprops[i].len; }
	uint8_t m[0x38]; memset(m, 0, sizeof m);
	fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
	wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, dl); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, dl);
	struct iovec v[2] = { { m, sizeof m }, { (void *)data, dl } };
	return ws_ipc_send(c->fd, v, dl ? 2 : 1, NULL, 0);
}

/* notification interests: 30379 SetConnectionNotifyInterests: count@0x20, ids from 0x24 (size 0x24 + 4n); 30378 SetProcessNotifyInterests: mode@0x20, count@0x24, ids from 0x28 */

/* replies whose only content is an out-of-line binary property list: complex 0x38, OOL@0x1c, NDR@0x2c, size repeated@0x34 */
extern const uint8_t sls_blob_displays[], sls_blob_devices[];
extern const unsigned sls_blob_displays_len, sls_blob_devices_len;
static int reply_ool_blob(conn *c, const mach_msg_header_t *h, const uint8_t *blob, unsigned n)
{
	uint8_t m[0x38]; memset(m, 0, sizeof m);
	fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
	wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, n); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, n);
	struct iovec v[2] = { { m, sizeof m }, { (void *)blob, n } };
	return ws_ipc_send(c->fd, v, 2, NULL, 0);
}


/* Routines a Cocoa app calls that had no handler. The request sizes are what the decompiled server routines check (header-only 0x18 for the first four,
 * 0x18 for DisconnectWindowManager, 0x24 for VirtualDisplayDestroy). There is no Dock, no right-to-left UI and no virtual display here, so the answers are the "nothing" values.
 * Unverified live: the exact error the real server gives for a virtual display that does not exist (1001, kCGErrorIllegalArgument, is assumed). */
static int do_system_ui_query(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	switch (h->msgh_id) {
	case SLS_MSG_GetAppearanceTheme: case SLS_MSG_GetSystemUIHasRTLDirection: case SLS_MSG_GetDebugOptions:
		if (!simple_ok(h, len, 0x18)) return -2;
		return reply_value(c->fd, h, 0);                                  /* light appearance, left-to-right, no debug options */
	case SLS_MSG_GetDockRectWithReason: {                               /* reply 0x3c: retcode, rect (4 floats), two u32: no Dock, empty rect */
		if (!simple_ok(h, len, 0x18)) return -2;
		uint8_t r[0x3c]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case SLS_MSG_DisconnectWindowManager:
		if (!simple_ok(h, len, 0x18)) return -2;
		return reply_simple(c->fd, h, 0);
	case SLS_MSG_VirtualDisplayDestroy:
		if (!simple_ok(h, len, 0x24)) return -2;
		return reply_simple(c->fd, h, 1001);
	}
	return -2;
}

/* GetSymbolicHotKeyValuesAndStates (32015): request = header, NDR, count@0x20 (<= 0x100), count hot key ids; size 0x24 + 4n (decompiled __XGetSymbolicHotKeyValuesAndStates).
 * Reply: retcode@0x20, n@0x24, array A (hot key character value, 4n bytes), then three more (n, array) pairs: key code, modifier mask, enabled; size 0x34 + 16n.
 * The session's symbolic hot key table is empty here (no system preferences): every entry is zero and disabled. */
static int do_symbolic_hotkeys(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x24) return -2;
	uint32_t n = rd32(buf, 0x20);
	if (n > 0x100 || h->msgh_size != 0x24 + 4 * n) return reply_simple(c->fd, h, -304);
	size_t rsize = 0x34 + 16 * (size_t)n;
	uint8_t *r = calloc(1, rsize);
	if (!r) return reply_simple(c->fd, h, 1000);
	fill_reply_header((mach_msg_header_t *)r, h, (uint32_t)rsize, 0);
	memcpy(r + 0x18, &WS_NDR, sizeof WS_NDR);
	wr32(r, 0x24, n);
	for (int k = 1; k <= 3; k++) wr32(r, 0x28 + 4 * n * k + 4 * (k - 1), n);    /* the count in front of each following array */
	int rc = ws_ipc_send(c->fd, &(struct iovec){ r, rsize }, 1, NULL, 0);
	free(r);
	return rc;
}

/* ---- WindowQuery stream encoding (transaction streams: packed64 integers, 0x48 + float, 0x88 + double) ---- */
typedef struct { uint8_t *p; size_t n, cap; } wq_buf;
static void wq_put(wq_buf *b, const void *d, size_t n) { if (b->n + n > b->cap) { b->cap = (b->n + n) * 2 + 64; b->p = realloc(b->p, b->cap); } memcpy(b->p + b->n, d, n); b->n += n; }
static void wq_u8(wq_buf *b, uint8_t v) { wq_put(b, &v, 1); }
static void wq_u32(wq_buf *b, uint32_t v) { wq_put(b, &v, 4); }
static void wq_p64(wq_buf *b, int64_t v)
{
	if (v == 0 || v == -1) { wq_u8(b, v == 0 ? 0 : 1); return; }
	int nb = 1;
	if (v >= 0) { while (nb < 8 && ((uint64_t)v >> (8 * nb))) nb++; }
	else { while (nb < 8 && v < -((int64_t)1 << (8 * nb - 1))) nb++; }
	wq_u8(b, (uint8_t)((nb << 4) | (v < 0 ? 1 : 0)));
	for (int i = nb - 1; i >= 0; i--) wq_u8(b, (uint8_t)((uint64_t)v >> (8 * i)));
}
static int wq_get_p64(const uint8_t *s, size_t n, size_t *i, int64_t *out)
{
	if (*i >= n) return 0;
	uint8_t t = s[(*i)++];
	if (t < 0x10) { *out = -(int64_t)(t & 1); return 1; }
	int nb = t >> 4;
	if (nb > 8 || *i + nb > n) return 0;
	uint64_t v = 0;
	for (int k = 0; k < nb; k++) v = (v << 8) | s[(*i)++];
	if (t & 1 && nb < 8) { uint64_t sign = (uint64_t)1 << (8 * nb - 1); v = (v ^ sign) - sign; }
	*out = (int64_t)v;
	return 1;
}
static void wq_rect(wq_buf *b, int x, int y, int w, int h) { wq_p64(b, x); wq_p64(b, y); wq_p64(b, w); wq_p64(b, h); }

/* one window record as the decompiled encode_window writes it (unverified live: values the model does not have are the ones the real server wrote for a plain window) */
static void wq_window(wq_buf *b, ws_wid id)
{
	ws_rect f = { 0, 0, 0, 0 }; int level = 0; float alpha = 1.0f;
	ws_window_frame(srv, id, &f); ws_window_level(srv, id, &level); ws_window_alpha(srv, id, &alpha);
	uint32_t owner = ws_window_owner(srv, id); conn *oc = wsd_conn_by_id(owner);
	uint64_t tags = ws_window_tags(srv, id);
	ws_rect sh = f;
	if (ws_window_has_shadow(srv, id)) { sh.x -= 23; sh.y -= 15; sh.w += 46; sh.h += 46; }   /* shadow outsets as the real server reports them for an ordinary window */
	wq_u32(b, 0);
	wq_u8(b, 1);
	wq_p64(b, id); wq_p64(b, owner); wq_p64(b, ws_window_parent(srv, id)); wq_p64(b, oc ? oc->pid : 0); wq_p64(b, 0); wq_p64(b, 0);
	wq_p64(b, level);
	if ((float)(int)alpha == alpha) wq_p64(b, (int)alpha); else { wq_u8(b, 0x48); wq_put(b, &alpha, 4); }
	wq_rect(b, f.x, f.y, f.w, f.h); wq_rect(b, f.x, f.y, f.w, f.h);
	wq_rect(b, sh.x, sh.y, sh.w, sh.h); wq_rect(b, sh.x, sh.y, sh.w, sh.h);
	wq_p64(b, 0); wq_p64(b, 0);                                         /* corner radius, an unnamed field */
	wq_p64(b, (int64_t)(tags & 0xffffffffu)); wq_p64(b, (int64_t)(tags >> 32));
	wq_u8(b, 0); wq_u8(b, 0);                                            /* no window shape, one more flag */
	wq_u32(b, 0xffffffffu); wq_u32(b, 0xffffffffu); wq_u32(b, 0xffffffffu);   /* no name / space list / group */
	wq_u8(b, 0); wq_u8(b, 0); wq_u8(b, 0);
}

/* WindowQuery (30474), the engine behind window lists. Request (decompiled __XWindowQuery): complex bit clear, query flags (u64)@0x20, n@0x28 (<= 0x4000), an encoded
 * query stream of n bytes@0x2c, size = pad4(n) + 0x2c. The reply is a complex message with one out-of-line descriptor slot and an inline stream:
 * descriptor count 1@0x18, address@0x1c (0 when inline), 0x01000101@0x24, size@0x28 (0 when inline), NDR@0x2c, inline length@0x34, stream@0x38, then the OOL size again;
 * size = pad4(len) + 0x3c. The stream starts with three 0xffffffff slots (window / space / display index lists, filled in when a list is not empty).
 * Only the empty result is produced: wsd answers every query with no windows, no spaces and no displays (encode_window is not reproduced yet). */
static int do_window_query(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x2c || h->msgh_size > 0x402c) return reply_simple(c->fd, h, -304);
	uint32_t n = rd32(buf, 0x28);
	if (n > 0x4000 || h->msgh_size != ((n + 3) & ~3u) + 0x2c) return reply_simple(c->fd, h, -304);
	/* query stream: packed64 count, then count window ids. A count of 0 asks for every window matching the filters: recorded on a macOS runner, a short stream gives the
	 * ordered-in windows front to back, and a first option of 1 gives only the WindowServer-owned ones (none here). The remaining filters (owner, tags, spaces) are not decoded. */
	const uint8_t *q = buf + 0x2c; size_t qi = 0; int64_t cnt = 0;
	if (!wq_get_p64(q, n, &qi, &cnt) || cnt < 0 || cnt > 0x4000) cnt = 0;
	ws_wid ids[256]; int nids = 0;
	if (cnt == 0) {
		int64_t opt = 0;
		if (!wq_get_p64(q, n, &qi, &opt)) opt = 0;
		if (!(opt & 1)) nids = ws_list_windows(srv, 0, 1, ids, 256);
		if (nids > 256) nids = 256;
	} else {
		for (int64_t k = 0; k < cnt && nids < 256; k++) { int64_t id; if (!wq_get_p64(q, n, &qi, &id)) break; if (id > 0) ids[nids++] = (ws_wid)id; }
	}
	wq_buf b = { 0, 0, 0 };
	wq_u32(&b, 0xffffffffu); wq_u32(&b, 0xffffffffu); wq_u32(&b, 0xffffffffu);   /* window / space / display list offsets, patched below */
	uint32_t seen_id[256], seen_off[256]; int nseen = 0;
	uint32_t listoff[256]; int nlist = 0;
	for (int k = 0; k < nids; k++) {
		int64_t id = ids[k];
		if (!ws_window_exists(srv, (ws_wid)id) || nlist >= 256) continue;
		int at = -1;
		for (int j = 0; j < nseen; j++) if (seen_id[j] == (uint32_t)id) at = j;
		if (at < 0) {
			seen_id[nseen] = (uint32_t)id; seen_off[nseen] = (uint32_t)b.n + 4;       /* the offset of the marker byte, after the leading zero word */
			at = nseen++;
			wq_window(&b, (ws_wid)id);
		}
		listoff[nlist++] = seen_off[at];
	}
	if (nlist) {
		uint32_t at = (uint32_t)b.n;
		wq_u32(&b, (uint32_t)nlist);
		for (int j = 0; j < nlist; j++) wq_u32(&b, listoff[j]);
		memcpy(b.p, &at, 4);
	}
	if (b.n > 0x4000) { free(b.p); return reply_simple(c->fd, h, -304); }
	size_t pad = (b.n + 3) & ~(size_t)3, rsize = pad + 0x3c;
	uint8_t *r = calloc(1, rsize);
	if (!r) { free(b.p); return reply_simple(c->fd, h, 1000); }
	fill_reply_header((mach_msg_header_t *)r, h, (uint32_t)rsize, 1);
	wr32(r, 0x18, 1);
	wr32(r, 0x24, 0x01000101u);
	memcpy(r + 0x2c, &WS_NDR, sizeof WS_NDR);
	wr32(r, 0x34, (uint32_t)b.n);
	memcpy(r + 0x38, b.p, b.n);
	int rc = ws_ipc_send(c->fd, &(struct iovec){ r, rsize }, 1, NULL, 0);
	free(r); free(b.p);
	return rc;
}

int sls_session_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	{ int rc = do_system_ui_query(c, buf, len); if (rc != -2) return rc; }
	if (h->msgh_id == SLS_MSG_WindowQuery) return do_window_query(c, buf, len);
	if (h->msgh_id == SLS_MSG_GetSymbolicHotKeyValuesAndStates) { int rc = do_symbolic_hotkeys(c, buf, len); if (rc != -2) return rc; }
	if (h->msgh_id == SLS_MSG_CopyManagedDisplays || h->msgh_id == SLS_MSG_GetDevices) {
		if (!simple_ok(h, len, sizeof *h)) return reply_simple(c->fd, h, -304);
		return h->msgh_id == SLS_MSG_GetDevices ? reply_ool_blob(c, h, sls_blob_devices, sls_blob_devices_len) : reply_ool_blob(c, h, sls_blob_displays, sls_blob_displays_len);
	}
	if (h->msgh_id == SLS_MSG_SetConnectionProperty) return do_set_conn_property(c, buf, len);
	if (h->msgh_id == SLS_MSG_GetConnectionProperty) return do_get_conn_property(c, buf, len);
	if (h->msgh_id == SLS_MSG_SetConnectionNotifyInterests) {
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x24) return reply_simple(c->fd, h, -304);
		uint32_t n = rd32(buf, 0x20);
		if (n > 256 || h->msgh_size != 0x24 + 4 * n) return reply_simple(c->fd, h, -304);
		c->notify_n = n; memcpy(c->notify, buf + 0x24, 4 * n);
		return reply_simple(c->fd, h, 0);
	}
	if (h->msgh_id == SLS_MSG_SetProcessNotifyInterests) {
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x28) return reply_simple(c->fd, h, -304);
		uint32_t n = rd32(buf, 0x24);
		if (n > 256 || h->msgh_size != 0x28 + 4 * n || rd32(buf, 0x20) > 2) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, c->registered ? 0 : 1010);
	}
	if (h->msgh_id == SLS_MSG_SetKeyTranslationTable) {                                // complex: OOL table, size 0x38, descriptor size repeated @0x34
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x38 || len < 0x38 || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
		if (buf[0x27] != 1 || rd32(buf, 0x28) != rd32(buf, 0x34) || len != 0x38 + (size_t)rd32(buf, 0x28)) return reply_simple(c->fd, h, -300);
		return reply_simple(c->fd, h, 0);
	}
	if (h->msgh_id == SLS_MSG_CreateApplication) return do_create_application(c, buf, len);
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) && h->msgh_size == sizeof *h && len == sizeof *h) return sls_golden_reply(c, h);
	return -2;
}
void sls_session_owner_cleanup(uint32_t owner) { (void)owner; }
