/* Client library: builds the SkyLight-layout messages and exchanges them over the wsbsd transport. */
#include "ws_client.h"
#include "ws_ipc.h"
#include "ws_region.h"
#include "ws_evrec.h"
#include "ws_buffer.h"
#include "sls_wire.h"
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <poll.h>

#define DEFAULT_SOCKET "/tmp/wsd.sock"

struct ws_conn { int fd; int efd; int cid; };

static uint32_t f2bits(float f) { uint32_t v; memcpy(&v, &f, sizeof v); return v; }

static void fill_header(mach_msg_header_t *h, uint32_t size, int id, int complex)
{
	h->msgh_bits = (complex ? MACH_MSGH_BITS_COMPLEX : 0) | MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
	h->msgh_size = size; h->msgh_remote_port = 1; h->msgh_local_port = 1; h->msgh_voucher_port = 0; h->msgh_id = id;
}

/* Sends a request and waits for the reply; returns the reply length, the reply is written to rep (cap bytes). */
static ssize_t call(ws_conn *c, const struct iovec *iov, int n, void *rep, size_t cap, int *fds, int *nfds)
{
	int dummy[WS_IPC_MAX_FDS], dn = 0;
	if (ws_ipc_send(c->fd, iov, n, NULL, 0)) return -1;
	return ws_ipc_recv(c->fd, rep, cap, fds ? fds : dummy, nfds ? nfds : &dn);
}

/* simple routine: returns the reply's return code, or -1 on a transport failure */
static int simple_call(ws_conn *c, const void *req, size_t len)
{
	sls_simple_reply r;
	struct iovec v = { (void *)req, len };
	ssize_t got = call(c, &v, 1, &r, sizeof r, NULL, NULL);
	if (got != (ssize_t)sizeof r) return -1;
	return r.retcode;
}

ws_conn *ws_connect(const char *path)
{
	if (!path) path = getenv("WS_SOCKET") ? getenv("WS_SOCKET") : DEFAULT_SOCKET;
	ws_conn *c = calloc(1, sizeof *c);
	if (!c) return NULL;
	c->fd = ws_ipc_connect(path);
	c->efd = -1;
	if (c->fd < 0) { free(c); return NULL; }
	/* NewConnectionPort handshake: application name in, connection id and an event channel out */
	const char *app = "wsbsd-client";
	uint32_t n = (uint32_t)strlen(app) + 1, pad = (n + 3) & ~3u, size = pad + 0x54;
	uint8_t req[0x454]; memset(req, 0, sizeof req);
	sls_new_connection_head hd; memset(&hd, 0, sizeof hd);
	{ mach_msg_header_t hh; fill_header(&hh, size, SLS_MSG_NewConnectionPort, 1); memcpy(&hd.h, &hh, sizeof hh); }   /* hd is packed */
	hd.body.msgh_descriptor_count = 2;
	hd.port_a = (mach_msg_port_descriptor_t){ .disposition = MACH_MSG_TYPE_MOVE_SEND, .type = MACH_MSG_PORT_DESCRIPTOR };
	hd.port_b = hd.port_a;
	hd.ndr = WS_NDR; hd.name_len = n;
	memcpy(req, &hd, sizeof hd); memcpy(req + sizeof hd, app, n);
	sls_new_connection_rep r; int fds[WS_IPC_MAX_FDS], nfds = 0;
	struct iovec v = { req, size };
	ssize_t got = call(c, &v, 1, &r, sizeof r, fds, &nfds);
	if (got != (ssize_t)sizeof r || r.h.msgh_id != SLS_MSG_NewConnectionPort + 100 || r.body.msgh_descriptor_count != 2 ||
	    r.port2.name < 1 || (int)r.port2.name > nfds) {
		for (int i = 0; i < nfds; i++) close(fds[i]);
		close(c->fd); free(c); return NULL;
	}
	c->efd = fds[r.port2.name - 1];
	for (int i = 0; i < nfds; i++) if (i != (int)r.port2.name - 1) close(fds[i]);
	c->cid = (int)r.connection_id;
	return c;
}

void ws_disconnect(ws_conn *c) { if (c) { if (c->efd >= 0) close(c->efd); close(c->fd); free(c); } }

int ws_conn_event_fd(ws_conn *c) { return c->efd; }

int ws_conn_next_pushed_event(ws_conn *c, int timeout_ms, ws_event *out)
{
	struct pollfd p = { c->efd, POLLIN, 0 };
	if (poll(&p, 1, timeout_ms) <= 0 || !(p.revents & POLLIN)) return 0;
	wsx_event_msg m; int fds[WS_IPC_MAX_FDS], nfds = 0;
	if (ws_ipc_recv(c->efd, &m, sizeof m, fds, &nfds) != (ssize_t)sizeof m || m.h.msgh_id != WSX_EVENT_PUSH) return 0;
	*out = (ws_event){ m.type, m.wid, m.x, m.y, m.buttons, m.key, m.flags, m.dx, m.dy, m.continuous };
	return 1;
}

int ws_conn_pid_version(ws_conn *c, int cid, long *pid)
{
	sls_wid_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_ConnectionGetPIDAndVersion, 0); q.ndr = WS_NDR; q.wid = (uint32_t)cid;
	sls_pid_version_rep r; struct iovec v = { &q, sizeof q };
	ssize_t got = call(c, &v, 1, &r, sizeof r, NULL, NULL);
	if (got == (ssize_t)sizeof(sls_simple_reply)) return ((sls_simple_reply *)&r)->retcode;
	if (got != (ssize_t)sizeof r) return -1;
	*pid = (long)(uint32_t)r.value;
	return r.retcode;
}

int ws_cursor_warp(ws_conn *c, int x, int y, float interval)
{
	sls_warp_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_WarpCursorPosition, 0); q.ndr = WS_NDR; q.x = x; q.y = y; q.interval_bits = f2bits(interval);
	return simple_call(c, &q, sizeof q);
}

int ws_win_set_event_mask(ws_conn *c, ws_win *w, int mask)
{
	sls_eventmask_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_SetWindowEventMask, 0); q.ndr = WS_NDR; q.wid = w->id; q.level = mask;
	return simple_call(c, &q, sizeof q);
}

int ws_cursor_scale(ws_conn *c, float *scale)
{
	mach_msg_header_t q; fill_header(&q, sizeof q, SLS_MSG_GetCursorScale, 0);
	sls_value_reply r; struct iovec v = { &q, sizeof q };
	if (call(c, &v, 1, &r, sizeof r, NULL, NULL) != (ssize_t)sizeof r || r.retcode) return -1;
	memcpy(scale, &r.value, 4);
	return 0;
}

int ws_win_create(ws_conn *c, ws_rect f, int level, ws_win *out)
{
	uint8_t region[64];
	size_t rl = ws_region_serialize(&f, 1, region, sizeof region);
	if (!rl) return -1;
	sls_create_window_req q;
	memset(&q, 0, sizeof q);
	{ mach_msg_header_t qh; fill_header(&qh, sizeof q, SLS_MSG_CreateWindow, 1); memcpy(&q.h, &qh, sizeof qh); }   /* q is packed */
	q.body.msgh_descriptor_count = 1;
	q.region = (mach_msg_ool_descriptor_t){ .address = 0, .deallocate = 1, .copy = MACH_MSG_VIRTUAL_COPY, .type = MACH_MSG_OOL_DESCRIPTOR, .size = (uint32_t)rl };
	q.ndr = WS_NDR; q.window_type = 2; q.region_size = (uint32_t)rl;
	struct iovec v[2] = { { &q, sizeof q }, { region, rl } };
	sls_create_window_rep r;
	int fds[WS_IPC_MAX_FDS], nfds = 0;
	ssize_t got = call(c, v, 2, &r, sizeof r, fds, &nfds);
	if (got != (ssize_t)sizeof r || !(r.h.msgh_bits & MACH_MSGH_BITS_COMPLEX) || r.h.msgh_id != SLS_MSG_CreateWindow + 100 || r.body.msgh_descriptor_count != 1) {
		for (int i = 0; i < nfds; i++) close(fds[i]);
		return -1;
	}
	if (r.shmem.name < 1 || (int)r.shmem.name > nfds) { for (int i = 0; i < nfds; i++) close(fds[i]); return -1; }
	int pfd = fds[r.shmem.name - 1];
	for (int i = 0; i < nfds; i++) if (i != (int)r.shmem.name - 1) close(fds[i]);
	out->id = r.window_id;
	out->px = ws_surface_from_fd(pfd, f.w, f.h);
	close(pfd);
	if (!out->px) { ws_win_release(c, out); return -1; }
	if (level) {
		sls_level_req l; memset(&l, 0, sizeof l);
		fill_header(&l.h, sizeof l, SLS_MSG_SetWindowLevel, 0); l.ndr = WS_NDR; l.wid = out->id; l.level = level;
		simple_call(c, &l, sizeof l);
	}
	return 0;
}

int ws_win_order(ws_conn *c, ws_win *w, int mode, ws_wid rel)
{
	sls_order_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_OrderWindow, 0); q.ndr = WS_NDR; q.wid = w->id; q.op = mode; q.relative = rel;
	return simple_call(c, &q, sizeof q);
}

int ws_win_move(ws_conn *c, ws_win *w, int x, int y)
{
	sls_move_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_MoveWindow, 0); q.ndr = WS_NDR; q.wid = w->id; q.x = x; q.y = y;
	return simple_call(c, &q, sizeof q);
}

int ws_win_alpha(ws_conn *c, ws_win *w, float al)
{
	sls_alpha_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_SetWindowListAlpha, 0); q.ndr = WS_NDR; q.wid = w->id; q.alpha_bits = f2bits(al);
	return simple_call(c, &q, sizeof q);
}

int ws_win_blur(ws_conn *c, ws_win *w, int radius)
{
	uint8_t m[0x30]; memset(m, 0, sizeof m);
	fill_header((mach_msg_header_t *)m, sizeof m, SLS_MSG_SetWindowBackgroundBlurRadius, 0);
	memcpy(m + 0x18, &WS_NDR, 8); memcpy(m + 0x20, &w->id, 4); uint32_t r = (uint32_t)radius; memcpy(m + 0x24, &r, 4);
	return simple_call(c, m, sizeof m);
}

int ws_win_release(ws_conn *c, ws_win *w)
{
	sls_terminate_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_TerminateWindow, 0); q.ndr = WS_NDR; q.wid = w->id;
	ws_surface_free(w->px); w->px = NULL;
	return simple_call(c, &q, sizeof q);
}

/* ---- private extension calls ---- */
static int wsx_call(ws_conn *c, int id, const int32_t *a, int na, const char *s, wsx_rep *rep)
{
	wsx_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, id, 0); q.ndr = WS_NDR;
	for (int i = 0; i < na && i < 8; i++) q.a[i] = a[i];
	if (s) strncpy(q.s, s, sizeof q.s - 1);
	wsx_rep r;
	struct iovec v = { &q, sizeof q };
	ssize_t got = call(c, &v, 1, &r, sizeof r, NULL, NULL);
	if (got != (ssize_t)sizeof r || r.h.msgh_id != id + 100) return -1;
	if (rep) *rep = r;
	return r.retcode;
}

int ws_win_shadow(ws_conn *c, ws_win *w, int cr, int on) { int32_t a[3] = { (int32_t)w->id, cr, on }; return wsx_call(c, WSX_SET_SHADOW, a, 3, NULL, NULL); }
int ws_win_flush(ws_conn *c, ws_win *w) { int32_t a[1] = { (int32_t)w->id }; return wsx_call(c, WSX_FLUSH, a, 1, NULL, NULL); }
ws_wid ws_win_find(ws_conn *c, int x, int y)
{
	sls_find_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_FindWindow, 0); q.ndr = WS_NDR; q.x = x; q.y = y;
	sls_find_reply r; struct iovec v = { &q, sizeof q };
	if (call(c, &v, 1, &r, sizeof r, NULL, NULL) != (ssize_t)sizeof r || r.retcode) return 0;
	return r.wid;
}

static int wid_value(ws_conn *c, int id, uint32_t wid, int32_t *out)
{
	sls_wid_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, id, 0); q.ndr = WS_NDR; q.wid = wid;
	sls_value_reply r; struct iovec v = { &q, sizeof q };
	if (call(c, &v, 1, &r, sizeof r, NULL, NULL) < (ssize_t)sizeof(sls_simple_reply)) return -1;
	if (r.retcode) return r.retcode;
	*out = r.value;
	return 0;
}

int ws_win_set_level(ws_conn *c, ws_win *w, int level)
{
	sls_level_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_SetWindowLevel, 0); q.ndr = WS_NDR; q.wid = w->id; q.level = level;
	return simple_call(c, &q, sizeof q);
}
int ws_win_get_event_mask(ws_conn *c, ws_win *w, int *mask) { int32_t v = 0; int rc = wid_value(c, SLS_MSG_GetWindowEventMask, w->id, &v); if (!rc) *mask = v; return rc; }
int ws_win_is_ordered_in(ws_conn *c, ws_win *w, int *in) { int32_t v = 0; int rc = wid_value(c, SLS_MSG_WindowIsOrderedIn, w->id, &v); if (!rc) *in = (uint8_t)v; return rc; }
int ws_win_get_level(ws_conn *c, ws_win *w, int *level) { int32_t v = 0; int rc = wid_value(c, SLS_MSG_GetWindowLevel, w->id, &v); if (!rc) *level = v; return rc; }
int ws_win_get_alpha(ws_conn *c, ws_win *w, float *alpha) { int32_t v = 0; int rc = wid_value(c, SLS_MSG_GetWindowAlpha, w->id, &v); if (!rc) memcpy(alpha, &v, 4); return rc; }
int ws_win_count(ws_conn *c, int cid) { int32_t v = 0; return wid_value(c, SLS_MSG_GetWindowCount, (uint32_t)cid, &v) ? -1 : v; }
int ws_conn_id(ws_conn *c) { return c->cid; }
int ws_conn_fd(ws_conn *c) { return c->fd; }

int ws_win_get_bounds(ws_conn *c, ws_win *w, ws_rect *out)
{
	sls_wid_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_GetWindowFrameBounds, 0); q.ndr = WS_NDR; q.wid = w->id;
	sls_bounds_reply r; struct iovec v = { &q, sizeof q };
	ssize_t got = call(c, &v, 1, &r, sizeof r, NULL, NULL);
	if (got != (ssize_t)sizeof r) return got == (ssize_t)sizeof(sls_simple_reply) ? ((sls_simple_reply *)&r)->retcode : -1;
	if (r.retcode) return r.retcode;
	*out = (ws_rect){ (int)r.x, (int)r.y, (int)r.w, (int)r.ht };
	return 0;
}

int ws_win_get_owner(ws_conn *c, ws_win *w, int *owner, int *rights)
{
	sls_wid_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_GetWindowOwner, 0); q.ndr = WS_NDR; q.wid = w->id;
	sls_owner_reply r; struct iovec v = { &q, sizeof q };
	ssize_t got = call(c, &v, 1, &r, sizeof r, NULL, NULL);
	if (got != (ssize_t)sizeof r) return got == (ssize_t)sizeof(sls_simple_reply) ? ((sls_simple_reply *)&r)->retcode : -1;
	*owner = r.owner; *rights = r.rights;
	return 0;
}
int ws_inject_mouse(ws_conn *c, int x, int y, int b) { int32_t a[3] = { x, y, b }; return wsx_call(c, WSX_INJECT_MOUSE, a, 3, NULL, NULL); }
int ws_inject_key(ws_conn *c, int key, int down) { int32_t a[2] = { key, down }; return wsx_call(c, WSX_INJECT_KEY, a, 2, NULL, NULL); }

int ws_poll_event(ws_conn *c, ws_win *w, ws_event *e)
{
	int32_t a[1] = { (int32_t)w->id };
	wsx_rep r;
	if (wsx_call(c, WSX_NEXT_EVENT, a, 1, NULL, &r) || r.a[0] == WS_EV_NONE) return 0;
	*e = (ws_event){ .type = r.a[0], .wid = (ws_wid)r.a[1], .x = r.a[2], .y = r.a[3], .buttons = r.a[4], .key = r.a[5] };
	return 1;
}

int ws_screenshot(ws_conn *c, const char *path) { return wsx_call(c, WSX_SCREENSHOT, NULL, 0, path, NULL); }
int ws_screenshot_scene(ws_conn *c, const char *path) { int32_t a[1] = { 1 }; return wsx_call(c, WSX_SCREENSHOT, a, 1, path, NULL); }
int ws_server_quit(ws_conn *c) { return wsx_call(c, WSX_QUIT, NULL, 0, NULL, NULL); }

int ws_win_set_sublevel(ws_conn *c, ws_win *w, int sl)
{
	sls_sublevel_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_SetWindowSubLevel, 0); q.ndr = WS_NDR; q.wid = w->id; q.level = sl;
	return simple_call(c, &q, sizeof q);
}

int ws_win_get_sublevel(ws_conn *c, ws_win *w, int *sl) { int32_t v = 0; int rc = wid_value(c, SLS_MSG_GetWindowSubLevel, w->id, &v); if (!rc) *sl = v; return rc; }
int ws_win_onscreen_count(ws_conn *c, int cid) { int32_t v = 0; return wid_value(c, SLS_MSG_GetOnScreenWindowCount, (uint32_t)cid, &v) ? -1 : v; }

int ws_win_get_shape_bounds(ws_conn *c, ws_win *w, ws_rect *out)
{
	sls_wid_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_GetWindowShapeBounds, 0); q.ndr = WS_NDR; q.wid = w->id;
	sls_shape_bounds_reply r; struct iovec v = { &q, sizeof q };
	ssize_t got = call(c, &v, 1, &r, sizeof r, NULL, NULL);
	if (got != (ssize_t)sizeof r) return got == (ssize_t)sizeof(sls_simple_reply) ? ((sls_simple_reply *)&r)->retcode : -1;
	if (r.retcode) return r.retcode;
	*out = (ws_rect){ r.x, r.y, r.w, r.ht };
	return 0;
}

int ws_win_move_list(ws_conn *c, const ws_win *const *w, int n, int dx, int dy)
{
	if (n < 0 || n > SLS_LIST_MAX) return -1;
	uint32_t buf[11 + SLS_LIST_MAX];
	memset(buf, 0, sizeof buf);
	mach_msg_header_t h; fill_header(&h, 0x2c + 4 * (uint32_t)n, SLS_MSG_MoveWindowList, 0);
	memcpy(buf, &h, sizeof h); memcpy(buf + 6, &WS_NDR, 8);
	buf[8] = (uint32_t)dx; buf[9] = (uint32_t)dy; buf[10] = (uint32_t)n;
	for (int i = 0; i < n; i++) buf[11 + i] = w[i]->id;
	return simple_call(c, buf, 0x2c + 4 * (size_t)n);
}

int ws_win_order_list(ws_conn *c, const ws_win *const *w, const int *ops, const ws_wid *rel, int n)
{
	if (n < 0 || n > SLS_LIST_MAX) return -1;
	uint32_t buf[11 + 3 * SLS_LIST_MAX];
	memset(buf, 0, sizeof buf);
	uint32_t size = 0x2c + 12 * (uint32_t)n;
	mach_msg_header_t h; fill_header(&h, size, SLS_MSG_OrderWindowList, 0);
	memcpy(buf, &h, sizeof h); memcpy(buf + 6, &WS_NDR, 8);
	uint32_t *p = buf + 8;
	*p++ = (uint32_t)n; for (int i = 0; i < n; i++) *p++ = w[i]->id;
	*p++ = (uint32_t)n; for (int i = 0; i < n; i++) *p++ = (uint32_t)ops[i];
	*p++ = (uint32_t)n; for (int i = 0; i < n; i++) *p++ = rel[i];
	return simple_call(c, buf, size);
}

static int post_record(ws_conn *c, const uint8_t *rec, size_t n)
{
	uint8_t buf[sizeof(sls_post_event_head) + 512];
	uint32_t pad = ((uint32_t)n + 3) & ~3u, size = 0x38 + pad;
	if (n == 0 || n > 512) return -1;
	memset(buf, 0, sizeof buf);
	sls_post_event_head hd; memset(&hd, 0, sizeof hd);
	fill_header(&hd.h, size, SLS_MSG_PostEventRecord, 0); hd.ndr = WS_NDR; hd.record_len = (uint32_t)n;
	memcpy(buf, &hd, sizeof hd); memcpy(buf + sizeof hd, rec, n);
	return simple_call(c, buf, size);
}

int ws_post_event_record(ws_conn *c, const uint8_t *rec, size_t n) { return post_record(c, rec, n); }

int ws_post_mouse_event(ws_conn *c, int type, float x, float y, uint32_t flags, int click_state, int button)
{
	uint8_t rec[512];
	size_t n = ws_evrec_make_mouse(rec, sizeof rec, type, x, y, flags, click_state, button, 0);
	return n ? post_record(c, rec, n) : -1;
}

int ws_post_key_event(ws_conn *c, int down, int keycode, uint32_t flags)
{
	uint8_t rec[512];
	size_t n = ws_evrec_make_key(rec, sizeof rec, down, keycode, flags, 0, 0, 0, 0, 0x0a);
	return n ? post_record(c, rec, n) : -1;
}

/* ---- shared buffers and surfaces ---- */
#ifdef WS_GBM
static struct gbm_device *gbm_dev;
static int gbm_tried;
#endif

int ws_cbuf_create(ws_conn *c, int w, int h, ws_cbuf *out)
{
	memset(out, 0, sizeof *out);
	int ok = -1;
#ifdef WS_GBM
	const char *force = getenv("WS_BUFFER");
	if (!gbm_tried && !(force && !strcmp(force, "shm"))) {
		gbm_tried = 1;
		gbm_dev = ws_gbm_open(getenv("WS_RENDER_NODE") ? getenv("WS_RENDER_NODE") : "/dev/dri/renderD128");
	}
	if (gbm_dev) ok = ws_buffer_create_gbm(&out->buf, gbm_dev, w, h);
#endif
	if (ok) ok = ws_buffer_create_shm(&out->buf, w, h, WS_FOURCC_ARGB8888);       /* fallback: no DRM/GBM available */
	if (ok) return -1;

	wsx_buffer_import_req q; memset(&q, 0, sizeof q);
	{ mach_msg_header_t hh; fill_header(&hh, sizeof q, WSX_BUFFER_IMPORT, 1); memcpy(&q.h, &hh, sizeof hh); }
	q.body.msgh_descriptor_count = 1;
	q.plane[0] = (mach_msg_port_descriptor_t){ .name = 1, .disposition = MACH_MSG_TYPE_MOVE_SEND, .type = MACH_MSG_PORT_DESCRIPTOR };
	q.ndr = WS_NDR; q.kind = out->buf.kind; q.width = w; q.height = h; q.fourcc = out->buf.fourcc; q.nplanes = 1;
	q.stride[0] = out->buf.stride[0]; q.offset[0] = out->buf.offset[0]; q.modifier = out->buf.modifier;
	struct iovec v = { &q, sizeof q };
	if (ws_ipc_send(c->fd, &v, 1, &out->buf.fd[0], 1)) { ws_buffer_close(&out->buf); return -1; }   /* the descriptor is duplicated by the kernel */
	sls_value_reply r;
	int fds[WS_IPC_MAX_FDS], nfds = 0;
	ssize_t got = ws_ipc_recv(c->fd, &r, sizeof r, fds, &nfds);
	if (got != (ssize_t)sizeof r || r.retcode || r.h.msgh_id != WSX_BUFFER_IMPORT + 100) { ws_buffer_close(&out->buf); return -1; }
	out->id = (uint32_t)r.value;
	return 0;
}

int ws_cbuf_release(ws_conn *c, ws_cbuf *b)
{
	wsx_buffer_release_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, WSX_BUFFER_RELEASE, 0); q.ndr = WS_NDR; q.level = (int32_t)b->id;
	int rc = simple_call(c, &q, sizeof q);
	ws_buffer_close(&b->buf);
	b->id = 0;
	return rc;
}

int ws_surface_add(ws_conn *c, ws_win *w, uint32_t *sid)
{
	int32_t v = 0;
	int rc = wid_value(c, SLS_MSG_AddSurface, w->id, &v);
	if (!rc) *sid = (uint32_t)v;
	return rc;
}

int ws_surface_remove(ws_conn *c, ws_win *w, uint32_t sid)
{
	sls_surface_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_RemoveSurface, 0); q.ndr = WS_NDR; q.wid = w->id; q.level = (int32_t)sid;
	return simple_call(c, &q, sizeof q);
}

static int bind_call(ws_conn *c, ws_win *w, uint32_t sid, int kind, uint32_t a, uint32_t b)
{
	sls_bind_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_BindSurface, 0); q.ndr = WS_NDR; q.wid = w->id; q.sid = sid; q.kind = kind; q.a = a; q.b = b;
	return simple_call(c, &q, sizeof q);
}

int ws_surface_bind_buffer(ws_conn *c, ws_win *w, uint32_t sid, const ws_cbuf *b) { return bind_call(c, w, sid, SLS_BIND_CONTEXT, 0, b->id); }
int ws_surface_unbind(ws_conn *c, ws_win *w, uint32_t sid) { return bind_call(c, w, sid, SLS_BIND_NONE, 0, 0); }

int ws_surface_binding(ws_conn *c, ws_win *w, uint32_t sid, int *kind, uint32_t *a, uint32_t *b)
{
	sls_surface_req q; memset(&q, 0, sizeof q);
	fill_header(&q.h, sizeof q, SLS_MSG_GetSurfaceBinding, 0); q.ndr = WS_NDR; q.wid = w->id; q.level = (int32_t)sid;
	sls_binding_reply r; struct iovec v = { &q, sizeof q };
	ssize_t got = call(c, &v, 1, &r, sizeof r, NULL, NULL);
	if (got == (ssize_t)sizeof(sls_simple_reply)) return ((sls_simple_reply *)&r)->retcode;
	if (got != (ssize_t)sizeof r) return -1;
	*kind = r.kind; *a = r.a; *b = r.b;
	return r.retcode;
}

int ws_surface_flush(ws_conn *c, ws_win *w, uint32_t sid, const ws_rect *dirty)
{
	uint8_t region[128]; size_t rl = 0;
	if (dirty) { rl = ws_region_serialize(dirty, 1, region, sizeof region); if (!rl) return -1; }
	sls_flush_surface_req q; memset(&q, 0, sizeof q);
	{ mach_msg_header_t hh; fill_header(&hh, sizeof q, SLS_MSG_FlushSurface, 1); memcpy(&q.h, &hh, sizeof hh); }
	q.body.msgh_descriptor_count = 1;
	q.region = (mach_msg_ool_descriptor_t){ .deallocate = 1, .copy = MACH_MSG_VIRTUAL_COPY, .type = MACH_MSG_OOL_DESCRIPTOR, .size = (uint32_t)rl };
	q.ndr = WS_NDR; q.wid = w->id; q.sid = sid; q.region_size = (uint32_t)rl;
	struct iovec v[2] = { { &q, sizeof q }, { region, rl } };
	sls_simple_reply r;
	ssize_t got = call(c, v, rl ? 2 : 1, &r, sizeof r, NULL, NULL);
	return got == (ssize_t)sizeof r ? r.retcode : -1;
}

int ws_win_list(ws_conn *c, int owner, int onscreen, uint32_t *out, int max, int *total)
{
	uint8_t q[0x3c]; memset(q, 0, sizeof q);
	fill_header((mach_msg_header_t *)q, sizeof q, SLS_MSG_GetWindowListWithTags, 0); memcpy(q + 0x18, &WS_NDR, 8);
	uint32_t o = (uint32_t)owner, m = (uint32_t)max; memcpy(q + 0x20, &o, 4); memcpy(q + 0x24, &m, 4); q[0x28] = (uint8_t)onscreen;
	uint8_t r[0x2c + 4 * 0x400]; struct iovec v = { q, sizeof q };
	ssize_t got = call(c, &v, 1, r, sizeof r, NULL, NULL);
	if (got < (ssize_t)sizeof(sls_simple_reply)) return -1;
	int32_t rc; memcpy(&rc, r + 0x20, 4);
	if (rc) return rc;
	uint32_t n; memcpy(&n, r + 0x24, 4);
	if (got < (ssize_t)(0x2c + 4 * n)) return -1;
	for (uint32_t i = 0; i < n && (int)i < max; i++) memcpy(&out[i], r + 0x28 + 4 * i, 4);
	if (total) { uint32_t t; memcpy(&t, r + 0x28 + 4 * n, 4); *total = (int)t; }
	return 0;
}

void ws_raw_header(uint8_t *m, uint32_t size, int id) { fill_header((mach_msg_header_t *)m, size, id, 0); }
int ws_raw_simple(ws_conn *c, const void *req, size_t n) { return simple_call(c, req, n); }

/* ---- transactions: stream builder and commit (format: src/sls_transaction.c) ---- */
size_t ws_tx_packed(uint8_t *out, int64_t v)
{
	if (v == 0) { out[0] = 0x00; return 1; }
	if (v == -1) { out[0] = 0x01; return 1; }
	int neg = v < 0, k = 1;
	for (; k < 8; k++) {                                          /* the fewest bytes whose sign extension gives v back */
		int64_t lo = -((int64_t)1 << (8 * k)), hi = ((int64_t)1 << (8 * k)) - 1;
		if (neg ? v >= lo : v <= hi) break;
	}
	out[0] = (uint8_t)(k << 4 | (neg ? 1 : 0));
	for (int i = 0; i < k; i++) out[1 + i] = (uint8_t)((uint64_t)v >> (8 * (k - 1 - i)));
	return 1 + (size_t)k;
}
size_t ws_tx_float(uint8_t *out, float f) { out[0] = 'H'; memcpy(out + 1, &f, 4); return 5; }
size_t ws_tx_double(uint8_t *out, double d) { out[0] = 0x88; memcpy(out + 1, &d, 8); return 9; }

int ws_transaction_commit(ws_conn *c, const uint8_t *stream, size_t n, int sync)
{
	if (n > 0x4000) return 1001;
	uint32_t P = ((uint32_t)n + 3) & ~3u, size = P + 0x48;
	uint8_t m[0x4048]; memset(m, 0, size);
	fill_header((mach_msg_header_t *)m, size, sync ? SLS_MSG_TransactionCommitSync : SLS_MSG_TransactionCommitAsync, 1);
	uint32_t one = 1; memcpy(m + 0x18, &one, 4); m[0x25] = 1; m[0x27] = 1;
	memcpy(m + 0x2c, &WS_NDR, 8);
	uint32_t il = (uint32_t)n; memcpy(m + 0x40, &il, 4); memcpy(m + 0x44, stream, n);
	return simple_call(c, m, size);
}

int ws_raw_call(ws_conn *c, const void *req, size_t n, void *reply, size_t cap)
{
	struct iovec v = { (void *)req, n };
	ssize_t got = call(c, &v, 1, reply, cap, NULL, NULL);
	if (got < (ssize_t)sizeof(sls_simple_reply)) return -1;
	int32_t rc; memcpy(&rc, (uint8_t *)reply + 0x20, 4);
	return rc;
}

/* ShapeWindow (30242): the window takes the bounds of the region (screen coordinates) as its frame */
int ws_win_set_frame(ws_conn *c, ws_win *w, ws_rect frame)
{
	uint8_t reg[256]; size_t rn = ws_region_serialize(&frame, 1, reg, sizeof reg);
	if (!rn) return -1;
	uint8_t m[0x58 + 256]; memset(m, 0, sizeof m);
	fill_header((mach_msg_header_t *)m, 0x58, SLS_MSG_ShapeWindow, 1);
	uint32_t two = 2, n32 = (uint32_t)rn; memcpy(m + 0x18, &two, 4); m[0x25] = 1; m[0x27] = 1; memcpy(m + 0x28, &n32, 4); m[0x35] = 1; m[0x37] = 1;
	memcpy(m + 0x3c, &WS_NDR, 8); memcpy(m + 0x44, &w->id, 4); memcpy(m + 0x50, &n32, 4); memcpy(m + 0x58, reg, rn);
	return simple_call(c, m, 0x58 + rn);
}
int ws_win_set_resolution(ws_conn *c, ws_win *w, float scale)
{
	uint8_t m[0x28]; memset(m, 0, sizeof m);
	fill_header((mach_msg_header_t *)m, sizeof m, SLS_MSG_SetWindowResolution, 0);
	memcpy(m + 0x18, &WS_NDR, 8); memcpy(m + 0x20, &w->id, 4); memcpy(m + 0x24, &scale, 4);
	return simple_call(c, m, sizeof m);
}
int ws_win_get_resolution(ws_conn *c, ws_win *w, float *scale)
{
	int32_t v = 0; int rc = wid_value(c, SLS_MSG_GetWindowResolution, w->id, &v);
	if (!rc) memcpy(scale, &v, 4);
	return rc;
}
