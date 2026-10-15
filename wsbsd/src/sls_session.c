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

int sls_session_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	{ int rc = do_system_ui_query(c, buf, len); if (rc != -2) return rc; }
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
