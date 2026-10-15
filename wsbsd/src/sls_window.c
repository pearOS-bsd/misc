/* Window routines beyond the core set in wsd.c: properties, layer context binding, ordered-in query. */
#include "wsd_priv.h"
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
	wr32(m, 0x18, 1); m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, n);                 /* one OOL descriptor, then the record and the size */
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
static int ool_request(const mach_msg_header_t *h, const uint8_t *buf, size_t len, uint32_t want_size, int *err)
{
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != want_size || len < want_size || rd32(buf, 0x18) != 1) { *err = -304; return -1; }
	uint32_t osz = rd32(buf, 0x28);
	if (buf[0x27] != 1) { *err = -300; return -1; }
	if (len != (size_t)want_size + osz) { *err = -304; return -1; }
	return (int)osz;
}

int sls_window_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	switch (h->msgh_id) {
	case SLS_MSG_SetWindowOpaqueShape: {                                           /* OOL region, wid@0x34, region size@0x38 (= descriptor size), size 0x3c */
		int err; int osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x38)) return reply_simple(c->fd, h, -300);
		(void)holds_rights(c, rd32(buf, 0x34));                                     /* the opaque shape only helps the compositor skip work: accepted, not used yet */
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_AddStructuralRegionOfType: {                                      /* OOL region, size 0x58; tracking/structural regions are accepted and not delivered yet */
		int err; int osz = ool_request(h, buf, len, 0x58, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if ((uint32_t)osz != rd32(buf, 0x48)) return reply_simple(c->fd, h, -300);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_CopySpacesForWindows: {                                           /* OOL array of window ids (count@0x38 = size/4); reply OOL array of space ids (u64) */
		int err; int osz = ool_request(h, buf, len, 0x3c, &err);
		if (osz < 0) return reply_simple(c->fd, h, err);
		if (rd32(buf, 0x38) != (uint32_t)osz / 4) return reply_simple(c->fd, h, -300);
		uint32_t count = (uint32_t)osz / 4;
		uint64_t *spaces = malloc(count * 8 + 8);
		if (!spaces) return reply_simple(c->fd, h, 1000);
		for (uint32_t i = 0; i < count; i++) spaces[i] = 1;                         /* one space */
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, count * 8); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, count);
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

void sls_window_owner_cleanup(uint32_t owner) { (void)owner; purge_dead(); }
