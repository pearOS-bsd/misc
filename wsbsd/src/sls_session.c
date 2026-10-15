/* Connection / session / process level routines: version, session ports, client dictionaries, debug options, appearance. */
#include "wsd_priv.h"
#include <string.h>
#include <stdio.h>

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

int sls_session_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (h->msgh_id == SLS_MSG_CreateApplication) return do_create_application(c, buf, len);
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) && h->msgh_size == sizeof *h && len == sizeof *h) return sls_golden_reply(c, h);
	return -2;
}
void sls_session_owner_cleanup(uint32_t owner) { (void)owner; }
