/* wsd: the window server daemon. kqueue loop, SOCK_SEQPACKET + SCM_RIGHTS transport carrying SkyLight-layout MIG messages,
 * shared-memory backing stores, software compositor. Display backend: headless (PPM) or FreeBSD KMS (untested).
 * Protocol facts: docs/SPEC-SLS-WIRE.md. */
#include "ws.h"
#include "ws_backend.h"
#include "ws_ipc.h"
#include "ws_region.h"
#include "ws_evrec.h"
#include "ws_input.h"
#include "ws_buffer.h"
#ifdef WS_GL
#include "ws_gl.h"
#endif
#include "sls_wire.h"
#include "wsd_priv.h"
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <time.h>
#include <sys/event.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <sys/un.h>
#ifdef __FreeBSD__
#include <sys/param.h>
#include <sys/ucred.h>
#endif
#include <fcntl.h>
#include <math.h>

#define DEFAULT_SOCKET ws_default_socket_path()
#define MAXCONN 128

ws_server *srv;
int wsd_screen_w = 1280, wsd_screen_h = 800;
static ws_surface *screen;
static int running = 1;
int wsd_dirty;
#define dirty wsd_dirty
static void cursors_owner_cleanup(uint32_t owner);
int wsd_vnc_read(ws_server *srv, ws_input *in, int sw, int sh, const char *name);
static int test_mode;          /* -t: enables the private test requests (screenshot to a file, input injection, quit) */
static uint8_t rbuf[WS_IPC_RECV_CAP];        /* receive buffer: requests are parsed in place, nothing is allocated per message */

static conn conns[MAXCONN];
static uint32_t next_conn = 1;

#ifdef WS_GL
static gl_compositor *glc;           /* NULL: the software compositor renders */
static int gl_failures;
#endif

/* Renders the scene (windows only) into dst: GL when available (with a software fallback for a failed frame), else software.
 * The cursor is separate: it is blended afterwards when with_cursor is set (screenshots, no hardware cursor plane). */
static void render_frame(ws_surface *dst, int with_cursor)
{
	int done = 0;
#ifdef WS_GL
	if (glc) {
		if (compositor_render_frame(glc, srv) == 0 && glc_read_pixels(glc, dst) == 0) { gl_failures = 0; done = 1; }
		else if (++gl_failures >= 3) { fprintf(stderr, "wsd: GL compositor keeps failing, falling back to software\n"); glc_destroy(glc); glc = NULL; }
	}
#endif
	if (!done) ws_compose_scene(srv, dst);
	if (with_cursor) ws_draw_cursor(srv, dst);
}

/* shared buffers registered by clients (the IOSurface counterpart) and the surface slots bound to them */
#define MAXBUF 256
#define MAXSURF 512
static ws_buffer bufs[MAXBUF];
static uint32_t next_buf = 1;
typedef struct { int used; uint32_t wid, sid; int kind; uint32_t a, b; uint32_t owner; int32_t ox, oy; uint8_t opaque; float alpha; } surf;
static surf surfs[MAXSURF];
static uint32_t next_sid = 0x100;                   /* the real server's CGXCreateSurfaceID starts at 0x100 (recorded) */

static ws_buffer *buf_by_id(uint32_t id) { for (int i = 0; i < MAXBUF; i++) if (bufs[i].id == id && id) return &bufs[i]; return NULL; }
static surf *surf_find(uint32_t wid, uint32_t sid) { for (int i = 0; i < MAXSURF; i++) if (surfs[i].used && surfs[i].wid == wid && surfs[i].sid == sid) return &surfs[i]; return NULL; }
static void surf_unbind(surf *sf) { if (sf->kind == SLS_BIND_CONTEXT) ws_window_set_content(srv, sf->wid, NULL, 0); sf->kind = 0; sf->a = sf->b = 0; }
static void buf_release(ws_buffer *b)
{
#ifdef WS_GL
	if (glc) glc_forget_buffer(glc, b->id);
#endif
	if (b->cpu) ws_server_drop_content(srv, b->cpu);
	for (int i = 0; i < MAXSURF; i++) if (surfs[i].used && surfs[i].kind == SLS_BIND_CONTEXT && surfs[i].b == b->id) { surfs[i].kind = 0; surfs[i].b = 0; }
	ws_buffer_close(b);
	memset(b, 0, sizeof *b);
}
void wsd_rights_cleanup(uint32_t cid);
static void owner_cleanup(uint32_t owner)
{
	wsd_rights_cleanup(owner);
	sls_ext_owner_cleanup(owner);
	cursors_owner_cleanup(owner);
	for (int i = 0; i < MAXSURF; i++) if (surfs[i].used && surfs[i].owner == owner) surfs[i].used = 0;
	for (int i = 0; i < MAXBUF; i++) if (bufs[i].id && bufs[i].owner == owner) buf_release(&bufs[i]);
}






/* ---- registered cursors (SetRegisteredCursor & co.): named cursors, per connection or global; the image is BGRA premultiplied ---- */
typedef struct {
	int used, global; uint32_t owner;
	char name[SLS_CURSOR_NAME_MAX + 1];
	uint32_t cols, rows, frames, wpts, hpts, duration; int hotx_px, hoty_px;
	uint8_t *px;                                                  /* cols * rows * frames pixels, frames stacked vertically */
} cursor_entry;
#define MAXCURSORS 64
static cursor_entry cursors[MAXCURSORS];

static cursor_entry *cursor_find(uint32_t owner, const char *name)
{
	cursor_entry *g = NULL;
	for (int i = 0; i < MAXCURSORS; i++) if (cursors[i].used && !strcmp(cursors[i].name, name)) {
		if (!cursors[i].global && cursors[i].owner == owner) return &cursors[i];          /* the connection's own cursor first */
		if (cursors[i].global) g = &cursors[i];
	}
	return g;
}
static void cursor_free(cursor_entry *e) { free(e->px); memset(e, 0, sizeof *e); }
static void cursors_owner_cleanup(uint32_t owner) { for (int i = 0; i < MAXCURSORS; i++) if (cursors[i].used && !cursors[i].global && cursors[i].owner == owner) cursor_free(&cursors[i]); }

/* the cursor image the screen shows: the first frame, scaled to its size in points, hotspot converted from pixels to points */
static void cursor_apply(const cursor_entry *e)
{
	int w = (int)e->wpts, h = (int)e->hpts;
	ws_surface *img = ws_surface_new(w, h);
	if (!img) return;
	for (int y = 0; y < h; y++)
		for (int x = 0; x < w; x++) {
			uint32_t sx = (uint32_t)((uint64_t)x * e->cols / (uint32_t)w), sy = (uint32_t)((uint64_t)y * e->rows / (uint32_t)h);
			memcpy(img->px + (size_t)y * img->stride + (size_t)x * 4, e->px + ((size_t)sy * e->cols + sx) * 4, 4);
		}
	ws_server_set_cursor_image(srv, img, (int)((double)e->hotx_px / e->cols * w), (int)((double)e->hoty_px / e->rows * h));
	ws_surface_free(img);
}

/* the name in a name request: offset@0x20 ignored, length@0x24, bytes@0x28; size must be pad4(length) + extra */
static int cursor_name(const mach_msg_header_t *h, const uint8_t *buf, size_t len, uint32_t extra, char *out)
{
	if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x28 || h->msgh_size > 0xa8 + extra) return 0;
	uint32_t n; memcpy(&n, buf + 0x24, 4);
	if (n > SLS_CURSOR_NAME_MAX || h->msgh_size != ((n + 3) & ~3u) + 0x28 + extra) return 0;
	memcpy(out, buf + 0x28, n); out[n] = 0;
	out[strnlen(out, n)] = 0;
	return 1;
}

static int do_cursor_register(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len < 0x68 || h->msgh_size < 0x68 || h->msgh_size > 0xe8 || len < h->msgh_size) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	uint32_t count, nlen, oolsize; uint8_t otype = buf[0x27];
	memcpy(&count, buf + 0x18, 4); memcpy(&oolsize, buf + 0x28, 4); memcpy(&nlen, buf + 0x38, 4);
	if (count != 1) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	if (otype != MACH_MSG_OOL_DESCRIPTOR) return reply_simple(c->fd, h, MIG_TYPE_ERROR);
	if (nlen > SLS_CURSOR_NAME_MAX) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	uint32_t P = (nlen + 3) & ~3u;
	if (h->msgh_size != P + 0x68 || len != (size_t)h->msgh_size + oolsize) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	uint32_t f[11]; memcpy(f, buf + 0x3c + P, sizeof f);                  /* global, set_now, cols, rows, wpts, hpts, hotx, hoty, npix, frames, duration */
	if (f[8] != oolsize / 4) return reply_simple(c->fd, h, MIG_TYPE_ERROR);
	uint32_t cols = f[2], rows = f[3], wpts = f[4], hpts = f[5], frames = f[9], npix = f[8];
	if (wpts > 0x400 || hpts > 0x400 || !wpts || !hpts || !cols || !rows || !frames || (uint64_t)cols * rows * frames > npix) return reply_simple(c->fd, h, CGS_ERROR_ILLEGAL_ARGUMENT);   /* 1001 */
	char name[SLS_CURSOR_NAME_MAX + 1]; memcpy(name, buf + 0x3c, nlen); name[nlen] = 0; name[strnlen(name, nlen)] = 0;
	cursor_entry tmp = { .used = 1, .global = (uint8_t)f[0], .owner = c->id, .cols = cols, .rows = rows, .frames = frames, .wpts = wpts, .hpts = hpts,
	                     .duration = f[10], .hotx_px = (int)f[6], .hoty_px = (int)f[7] };
	snprintf(tmp.name, sizeof tmp.name, "%s", name);
	tmp.px = malloc((size_t)cols * rows * frames * 4);
	if (!tmp.px) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
	memcpy(tmp.px, buf + h->msgh_size, (size_t)cols * rows * frames * 4);
	if (name[0]) {                                                        /* replaces an entry of the same name and scope */
		for (int i = 0; i < MAXCURSORS; i++) if (cursors[i].used && !strcmp(cursors[i].name, name) && cursors[i].global == tmp.global && (tmp.global || cursors[i].owner == c->id)) cursor_free(&cursors[i]);
		cursor_entry *slot = NULL;
		for (int i = 0; i < MAXCURSORS && !slot; i++) if (!cursors[i].used) slot = &cursors[i];
		if (!slot) { free(tmp.px); return reply_simple(c->fd, h, CGS_ERROR_FAILURE); }
		*slot = tmp;
		if (f[1]) cursor_apply(slot);
	} else if (f[1]) { cursor_apply(&tmp); free(tmp.px); }
	else { free(tmp.px); return reply_simple(c->fd, h, 1001); }           /* an unnamed cursor must be set at once */
	return reply_value(c->fd, h, f[1] ? (int32_t)ws_cursor_serial(srv) : 0);
}

static int do_cursor_get_data(conn *c, const mach_msg_header_t *h, const cursor_entry *e)
{
	uint32_t bytes = e->cols * e->rows * e->frames * 4;
	uint8_t m[0x58]; memset(m, 0, sizeof m);
	mach_msg_header_t *r = (mach_msg_header_t *)m;
	fill_reply_header(r, h, sizeof m, 1);
	uint32_t one = 1; memcpy(m + 0x18, &one, 4);                          /* descriptor count */
	m[0x24] = 0; m[0x25] = 1; m[0x26] = 0; m[0x27] = MACH_MSG_OOL_DESCRIPTOR;
	memcpy(m + 0x28, &bytes, 4);
	memcpy(m + 0x2c, &WS_NDR, 8);
	uint32_t v[9] = { e->cols, e->rows * e->frames, e->wpts, e->hpts,                    /* size in points first, then the hotspot (verified live) */
	                  (uint32_t)((double)e->hotx_px / e->cols * e->wpts), (uint32_t)((double)e->hoty_px / e->rows * e->hpts), bytes, e->frames, e->duration };
	memcpy(m + 0x34, v, sizeof v);
	struct iovec iov[2] = { { m, sizeof m }, { e->px, bytes } };         /* out-of-line data follows the message in the same datagram */
	return ws_ipc_send(c->fd, iov, 2, NULL, 0);
}

static int peer_pid(int fd)
{
#if defined(__APPLE__)
	int pid = 0; socklen_t l = sizeof pid;
	return getsockopt(fd, 0 /* SOL_LOCAL */, 2 /* LOCAL_PEERPID */, &pid, &l) == 0 ? pid : 0;
#elif defined(__FreeBSD__)
	struct xucred xu; socklen_t l = sizeof xu;
	return getsockopt(fd, 0 /* SOL_LOCAL */, LOCAL_PEERCRED, &xu, &l) == 0 ? xu.cr_pid : 0;
#else
	(void)fd; return 0;
#endif
}

#define conn_by_id wsd_conn_by_id

/* listen-only event taps: every event queued for a window is also serialized as a CGEvent record and offered to the taps (src/sls_tap.c) */
static void tap_deliver(const ws_event *e)
{
	int cg; uint8_t rec[512]; size_t n = 0; ws_rect f = { 0, 0, 0, 0 }; ws_window_frame(srv, e->wid, &f);
	float gx = (float)(f.x + e->x), gy = (float)(f.y + e->y);
	switch (e->type) {
	case WS_EV_MOUSE_MOVE: cg = 5; n = ws_evrec_make_mouse(rec, sizeof rec, cg, gx, gy, e->flags, 0, 0, 0); break;
	case WS_EV_MOUSE_DOWN: cg = (e->buttons & 2) ? 3 : 1; n = ws_evrec_make_mouse(rec, sizeof rec, cg, gx, gy, e->flags, 1, (e->buttons & 2) ? 1 : 0, 0); break;
	case WS_EV_MOUSE_UP: cg = (e->buttons & 2) ? 4 : 2; n = ws_evrec_make_mouse(rec, sizeof rec, cg, gx, gy, e->flags, 1, (e->buttons & 2) ? 1 : 0, 0); break;
	case WS_EV_KEY_DOWN: cg = 10; n = ws_evrec_make_key(rec, sizeof rec, 1, e->key, e->flags, gx, gy, 0, 0, 0x0a); break;
	case WS_EV_KEY_UP: cg = 11; n = ws_evrec_make_key(rec, sizeof rec, 0, e->key, e->flags, gx, gy, 0, 0, 0x0a); break;
	default: return;
	}
	if (n) sls_tap_deliver(cg, rec, n);
}

/* events queued for a window are also pushed to its owner's event channel, if the connection opened one */
static void push_event(void *ctx, uint32_t owner, const ws_event *e)
{
	(void)ctx;
	tap_deliver(e);
	conn *c = conn_by_id(owner);
	if (!c || c->efd < 0) return;
	wsx_event_msg m; memset(&m, 0, sizeof m);
	m.h.msgh_bits = MACH_MSG_TYPE_MOVE_SEND_ONCE; m.h.msgh_size = sizeof m; m.h.msgh_id = WSX_EVENT_PUSH;
	m.ndr = WS_NDR; m.type = e->type; m.wid = e->wid; m.x = e->x; m.y = e->y; m.buttons = e->buttons; m.key = e->key; m.flags = e->flags; m.dx = e->dx; m.dy = e->dy; m.continuous = e->continuous;
	struct iovec v = { &m, sizeof m };
	ws_ipc_send(c->efd, &v, 1, NULL, 0);                     /* non-blocking: a full channel drops the event */
}

static float bits2f(uint32_t v) { float f; memcpy(&f, &v, sizeof f); return f; }

/* ---- replies ---- */
void fill_reply_header(mach_msg_header_t *r, const mach_msg_header_t *req, uint32_t size, int complex)
{
	/* as a Mach receiver sees a MIG reply (recorded from the real server): remote disposition 0, local disposition 0x12 (the consumed send-once right) */
	r->msgh_bits = (complex ? MACH_MSGH_BITS_COMPLEX : 0) | (MACH_MSG_TYPE_MOVE_SEND_ONCE << 8);
	r->msgh_size = size;
	r->msgh_remote_port = 0; r->msgh_local_port = 0; r->msgh_voucher_port = 0;
	(void)req;
	r->msgh_id = req->msgh_id + 100;
}

#undef ws_ipc_send
#include "sls_zero_ndr.h"
int wsd_send(int sock, const struct iovec *iov, int iovcnt, const int *fds, int nfds)
{
	if (iovcnt == 1 && iov[0].iov_len == 36) {                          /* a kern-return-only reply: some routines leave the NDR record zero on success */
		uint8_t m[36]; memcpy(m, iov[0].iov_base, 36);
		const mach_msg_header_t *h = (const mach_msg_header_t *)m;
		int32_t ret; memcpy(&ret, m + 0x20, 4);
		if (ret != 0 && !(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) && h->msgh_id > 100 && !(ret <= -300 && ret >= -310)) {
			for (size_t k = 0; k < sizeof zero_ndr_err_ids / sizeof *zero_ndr_err_ids; k++)
				if ((uint32_t)zero_ndr_err_ids[k] + 100 == (uint32_t)h->msgh_id) { memset(m + 0x18, 0, 8); break; }
		}
		if (ret == 0 && !(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) && h->msgh_id > 100) {
			for (size_t k = 0; k < sizeof zero_ndr_ids / sizeof *zero_ndr_ids; k++)
				if ((uint32_t)zero_ndr_ids[k] + 100 == (uint32_t)h->msgh_id) { memset(m + 0x18, 0, 8); break; }
		}
		struct iovec v = { m, 36 };
		return ws_ipc_send(sock, &v, 1, fds, nfds);
	}
	return ws_ipc_send(sock, iov, iovcnt, fds, nfds);
}
#define ws_ipc_send wsd_send

int reply_simple(int fd, const mach_msg_header_t *req, int32_t retcode)
{
	sls_simple_reply r;
	memset(&r, 0, sizeof r);
	fill_reply_header(&r.h, req, sizeof r, 0);
	r.ndr = WS_NDR; r.retcode = retcode;
	struct iovec v = { &r, sizeof r };
	return ws_ipc_send(fd, &v, 1, NULL, 0);
}

int reply_mig_error(int fd, const mach_msg_header_t *req, int32_t code)
{
	sls_simple_reply r;
	memset(&r, 0, sizeof r);
	fill_reply_header(&r.h, req, sizeof r, 0);
	r.h.msgh_id = MACH_ERROR_REPLY_ID;           /* what a MIG server sends for an unknown id */
	r.ndr = WS_NDR; r.retcode = code;
	struct iovec v = { &r, sizeof r };
	return ws_ipc_send(fd, &v, 1, NULL, 0);
}

int reply_value(int fd, const mach_msg_header_t *req, int32_t value)
{
	sls_value_reply r;
	memset(&r, 0, sizeof r);
	fill_reply_header(&r.h, req, sizeof r, 0);
	r.ndr = WS_NDR; r.value = value;
	struct iovec v = { &r, sizeof r };
	return ws_ipc_send(fd, &v, 1, NULL, 0);
}

int simple_ok(const mach_msg_header_t *h, size_t len, size_t want)
{
	return !(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) && h->msgh_size == want && len == want;
}

/* ---- window rights: the owner holds everything; GrantConnectionRightsOnWindow offers rights to another connection, CompleteWindowRightsGrant accepts them, WindowRightsRelinquish gives them back ---- */
#define MAXRTS 256
#define MAXGRANTS 64
static struct { uint32_t wid, cid, mask; } rts[MAXRTS];
static struct { int used; uint32_t wid, recip, a, b, id; } grants[MAXGRANTS];
static uint32_t next_grant = 1;

uint32_t wsd_rights_held(const conn *c, uint32_t wid)
{
	if (!wid) return 0;
	if (ws_window_owner(srv, wid) == c->id) return 0x30007u;
	uint32_t m = 0;
	for (int i = 0; i < MAXRTS; i++) if (rts[i].wid == wid && rts[i].cid == c->id) m |= rts[i].mask;
	return m;
}
int holds_rights(const conn *c, uint32_t wid) { return wid && wsd_rights_held(c, wid) != 0; }

/* offers rights (a: the main set, b: reserved) on a window to a connection; the caller must be able to extend them. Returns the return code. */
int wsd_grant_create(conn *c, uint32_t recip, uint32_t wid, uint32_t a, uint32_t b)
{
	if (!wsd_conn_by_id(recip)) return 1001;                                     /* the recipient connection must exist */
	if (!ws_window_exists(srv, wid)) return 1001;
	for (int i = 0; i < MAXGRANTS; i++) if (grants[i].used && grants[i].wid == wid) return 1001;     /* one offer at a time */
	if ((a & b & 7) != 0) return 1001;
	if (!(a & 1) && b != 0) return 1001;
	if ((wsd_rights_held(c, wid) & (a | b | 1)) != (a | b | 1)) return 1001;       /* the caller lacks the privilege to extend these rights */
	for (int i = 0; i < MAXGRANTS; i++) if (!grants[i].used) { grants[i].used = 1; grants[i].wid = wid; grants[i].recip = recip; grants[i].a = a; grants[i].b = b; grants[i].id = next_grant++; return 0; }
	return 1000;
}
int wsd_grant_complete(conn *c, uint32_t wid, uint32_t id)
{
	for (int i = 0; i < MAXGRANTS; i++) if (grants[i].used && grants[i].wid == wid) {
		if (grants[i].recip != c->id) return 1010;                                 /* not the grant recipient */
		if (grants[i].id != id) return 1010;                                       /* grant id mismatch */
		for (int k = 0; k < MAXRTS; k++) if (!rts[k].wid) { rts[k].wid = wid; rts[k].cid = c->id; rts[k].mask = grants[i].a | grants[i].b; grants[i].used = 0; return 0; }
		return 1000;
	}
	return 1001;                                                                    /* no grant exists */
}
uint32_t wsd_grant_id(uint32_t wid) { for (int i = 0; i < MAXGRANTS; i++) if (grants[i].used && grants[i].wid == wid) return grants[i].id; return 0; }
int wsd_rights_relinquish(conn *c, uint32_t wid, uint32_t mask)
{
	if (!ws_window_exists(srv, wid) || (mask & 7)) return 1001;                      /* exclusive rights (1, 2, 4) cannot be relinquished */
	uint32_t held = 0; for (int i = 0; i < MAXRTS; i++) if (rts[i].wid == wid && rts[i].cid == c->id) held |= rts[i].mask;
	if (mask & ~held) return 1001;                                                  /* rights not directly held */
	for (int i = 0; i < MAXRTS; i++) if (rts[i].wid == wid && rts[i].cid == c->id) { rts[i].mask &= ~mask; if (!rts[i].mask) rts[i].wid = 0; }
	return 0;
}
void wsd_rights_cleanup(uint32_t cid)
{
	for (int i = 0; i < MAXRTS; i++) if (rts[i].cid == cid) rts[i].wid = 0;
	for (int i = 0; i < MAXGRANTS; i++) if (grants[i].used && grants[i].recip == cid) grants[i].used = 0;
}

/* ---- SkyLight routines ---- */
#define WSD_MAX_WINDOWS_PER_CONN 2048
#define WSD_MAX_BYTES_PER_CONN (1.0 * 1024 * 1024 * 1024)       /* 1 GiB of window backing per connection */
static int do_create_window(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != sizeof(sls_create_window_req) || len < h->msgh_size)
		return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	sls_create_window_req rq;
	memcpy(&rq, buf, sizeof rq);
	if (rq.body.msgh_descriptor_count != 1) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	if (rq.region.type != MACH_MSG_OOL_DESCRIPTOR || rq.region.size != rq.region_size || len != sizeof rq + rq.region.size)
		return reply_simple(c->fd, h, MIG_TYPE_ERROR);
	if (rq.window_type != 2 && rq.window_type != 3 && rq.window_type != 5)      /* mask 0x2c in the original */
		return reply_simple(c->fd, h, CGS_ERROR_ILLEGAL_ARGUMENT);
	ws_rect *rects; int n; ws_rect bounds;
	if (ws_region_parse(buf + sizeof rq, rq.region.size, &rects, &n, &bounds) || bounds.w <= 0 || bounds.h <= 0 || bounds.w > 8192 || bounds.h > 8192)
		return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
	{ int nw; double nb; ws_owner_usage(srv, c->id, &nw, &nb);                   /* a connection cannot exhaust the server: limits on windows and backing memory */
	  if (nw >= WSD_MAX_WINDOWS_PER_CONN || nb + (double)bounds.w * bounds.h * 4.0 > WSD_MAX_BYTES_PER_CONN) { free(rects); return reply_simple(c->fd, h, CGS_ERROR_FAILURE); } }
	int pfd = -1;
	ws_wid wid = ws_create_window_fd(srv, bounds, c->id, &pfd);
	if (!wid) { free(rects); return reply_simple(c->fd, h, CGS_ERROR_FAILURE); }
	ws_set_window_shape(srv, wid, rects, n);
	free(rects);
	sls_create_window_rep r;
	memset(&r, 0, sizeof r);
	{ mach_msg_header_t rh; fill_reply_header(&rh, h, sizeof r, 1); memcpy(&r.h, &rh, sizeof rh); }   /* r is packed */
	r.body.msgh_descriptor_count = 1;
	r.shmem = (mach_msg_port_descriptor_t){ .name = 1, .disposition = MACH_MSG_TYPE_MOVE_SEND, .type = MACH_MSG_PORT_DESCRIPTOR };
	r.ndr = WS_NDR; r.window_id = wid;
	struct iovec v = { &r, sizeof r };
	int rc = ws_ipc_send(c->fd, &v, 1, &pfd, 1);
	close(pfd);
	return rc;
}


/* surface operations shared by the direct requests and the transaction ops: return the retcode */
int wsd_remove_surface(conn *c, uint32_t wid, uint32_t sid)
{
	if (!holds_rights(c, wid)) return CGS_ERROR_FAILURE;
	surf *sf = surf_find(wid, sid);
	if (sf) { surf_unbind(sf); sf->used = 0; }
	return 0;
}

/* the ids of the surfaces of a window, oldest first (the list the window keeps); returns the count */
int wsd_window_surfaces(uint32_t wid, uint32_t *out, int max)
{
	int n = 0;
	for (int i = 0; i < MAXSURF; i++) if (surfs[i].used && surfs[i].wid == wid) { if (n < max) out[n] = surfs[i].sid; n++; }
	return n;
}

int wsd_remove_all_surfaces(conn *c, uint32_t wid)
{
	if (!ws_window_exists(srv, wid) || !holds_rights(c, wid)) return 1000;            /* needs write access to the window */
	for (int i = 0; i < MAXSURF; i++) if (surfs[i].used && surfs[i].wid == wid) { surf_unbind(&surfs[i]); surfs[i].used = 0; }
	return 0;
}

int wsd_bind_surface(conn *c, uint32_t wid, uint32_t sid, int kind, uint32_t a, uint32_t bid)
{
	if (!holds_rights(c, wid)) return CGS_ERROR_FAILURE;
	surf *sf = surf_find(wid, sid);
	if (!sf) return CGS_ERROR_ILLEGAL_ARGUMENT;                                                 /* "Invalid surface" */
	switch (kind) {
	case SLS_BIND_NONE: surf_unbind(sf); break;
	case SLS_BIND_INVALID: return CGS_ERROR_ILLEGAL_ARGUMENT;
	case SLS_BIND_CONTEXT: {
		ws_buffer *b = buf_by_id(bid);
		if (!b || b->owner != c->id) return CGS_ERROR_ILLEGAL_ARGUMENT;
		if (!b->cpu) return CGS_ERROR_FAILURE;                                                  /* neither a CPU view nor a GL import */
		surf_unbind(sf);
		sf->kind = SLS_BIND_CONTEXT; sf->a = a; sf->b = bid;
		ws_window_set_content(srv, sf->wid, b->cpu, b->id);
		break;
	}
	case SLS_BIND_WINDOW: case SLS_BIND_ACCEL: return CGS_ERROR_FAILURE;                       /* not supported by wsbsd */
	default: break;                                                                           /* unknown kinds fall through to success in the original */
	}
	return 0;
}

static int do_simple(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	switch (h->msgh_id) {
	case SLS_MSG_TerminateWindow: {
		if (!simple_ok(h, len, sizeof(sls_terminate_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_terminate_req *q = (const void *)buf;
		if (holds_rights(c, q->wid)) ws_release_window(srv, q->wid);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_MoveWindow: {
		if (!simple_ok(h, len, sizeof(sls_move_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_move_req *q = (const void *)buf;
		if (!holds_rights(c, q->wid)) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		ws_move_window(srv, q->wid, q->x, q->y);               /* absolute origin, as observed */
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_OrderWindow: {
		if (!simple_ok(h, len, sizeof(sls_order_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_order_req *q = (const void *)buf;
		if (!holds_rights(c, q->wid)) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		return reply_simple(c->fd, h, ws_order_window(srv, q->wid, q->op, q->relative) ? CGS_ERROR_FAILURE : 0);
	}
	case SLS_MSG_SetWindowLevel: {
		if (!simple_ok(h, len, sizeof(sls_level_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_level_req *q = (const void *)buf;
		if (holds_rights(c, q->wid)) ws_set_window_level(srv, q->wid, q->level);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowListAlpha: {
		if (!simple_ok(h, len, sizeof(sls_alpha_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_alpha_req *q = (const void *)buf;
		if (holds_rights(c, q->wid)) ws_set_window_alpha(srv, q->wid, bits2f(q->alpha_bits));
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetWindowLevel: {
		if (!simple_ok(h, len, sizeof(sls_wid_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		int lv;
		if (ws_window_level(srv, ((const sls_wid_req *)buf)->wid, &lv)) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		return reply_value(c->fd, h, lv);
	}
	case SLS_MSG_GetWindowAlpha: {
		if (!simple_ok(h, len, sizeof(sls_wid_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		float a = 0;                                           /* an unknown window still succeeds, with the value left at 0 */
		ws_window_alpha(srv, ((const sls_wid_req *)buf)->wid, &a);
		uint32_t bits; memcpy(&bits, &a, 4);
		return reply_value(c->fd, h, (int32_t)bits);
	}
	case SLS_MSG_GetWindowCount: {
		if (!simple_ok(h, len, sizeof(sls_wid_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		return reply_value(c->fd, h, ws_count_owned(srv, ((const sls_wid_req *)buf)->wid));   /* the argument is a connection id */
	}
	case SLS_MSG_GetWindowFrameBounds: {
		if (!simple_ok(h, len, sizeof(sls_wid_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		ws_rect f;
		if (ws_window_frame(srv, ((const sls_wid_req *)buf)->wid, &f)) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		sls_bounds_reply r; memset(&r, 0, sizeof r);
		{ mach_msg_header_t rh; fill_reply_header(&rh, h, sizeof r, 0); memcpy(&r.h, &rh, sizeof rh); }
		r.ndr = WS_NDR; r.x = f.x; r.y = f.y; r.w = f.w; r.ht = f.h;
		struct iovec v = { &r, sizeof r };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_GetWindowOwner: {
		if (!simple_ok(h, len, sizeof(sls_wid_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		uint32_t wid = ((const sls_wid_req *)buf)->wid, owner = ws_window_owner(srv, wid);
		if (!wid || !c->id || !owner) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		sls_owner_reply r; memset(&r, 0, sizeof r);
		fill_reply_header(&r.h, h, sizeof r, 0);
		r.ndr = WS_NDR; r.owner = (int32_t)owner;
		r.rights = holds_rights(c, wid) ? 0x30007 : 0;          /* recorded on a macOS runner: the owner holds 0x30007 */
		r.extra = 1;                                            /* recorded: window+0x8dc (the sharing state), 1 for an ordinary window */
		struct iovec v = { &r, sizeof r };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_FindWindow: {
		if (!simple_ok(h, len, sizeof(sls_find_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_find_req *q = (const void *)buf;
		uint32_t hit = ws_find_window(srv, q->x, q->y);        /* q->wid and the other fields are not understood yet */
		sls_find_reply r; memset(&r, 0, sizeof r);
		{ mach_msg_header_t rh; fill_reply_header(&rh, h, sizeof r, 0); memcpy(&r.h, &rh, sizeof rh); }
		r.ndr = WS_NDR; r.wid = hit; r.owner = hit ? ws_window_owner(srv, hit) : 0;
		struct iovec v = { &r, sizeof r };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_GetOnScreenWindowCount: {
		if (!simple_ok(h, len, sizeof(sls_wid_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		return reply_value(c->fd, h, ws_count_onscreen_owned(srv, ((const sls_wid_req *)buf)->wid));
	}
	case SLS_MSG_GetWindowSubLevel: {
		if (!simple_ok(h, len, sizeof(sls_wid_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		int sl;
		if (ws_window_sublevel(srv, ((const sls_wid_req *)buf)->wid, &sl)) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		return reply_value(c->fd, h, sl);
	}
	case SLS_MSG_SetWindowSubLevel: {
		if (!simple_ok(h, len, sizeof(sls_sublevel_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_sublevel_req *q = (const void *)buf;
		if (holds_rights(c, q->wid)) ws_set_window_sublevel(srv, q->wid, q->level);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetWindowShapeBounds: {
		if (!simple_ok(h, len, sizeof(sls_wid_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		ws_rect b;
		if (ws_window_shape_bounds(srv, ((const sls_wid_req *)buf)->wid, &b)) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		sls_shape_bounds_reply r; memset(&r, 0, sizeof r);
		fill_reply_header(&r.h, h, sizeof r, 0);
		r.ndr = WS_NDR; r.x = b.x; r.y = b.y; r.w = b.w; r.ht = b.h;
		struct iovec v = { &r, sizeof r };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_MoveWindowList: {                             /* variable length, validated like the original */
		const uint32_t *w = (const uint32_t *)buf;
		uint32_t size = h->msgh_size, n = len >= 0x2c ? w[10] : 0;
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || size < 0x2c || size > 0x102c || len != size || n > SLS_LIST_MAX || size != n * 4 + 0x2c)
			return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		if (n == 0) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		int32_t dx = (int32_t)w[8], dy = (int32_t)w[9];        /* the original passes these as a delta to CGXMoveWindowList */
		for (uint32_t i = 0; i < n; i++) {
			uint32_t wid = w[11 + i]; ws_rect f;
			if (holds_rights(c, wid) && !ws_window_frame(srv, wid, &f)) ws_move_window(srv, wid, f.x + dx, f.y + dy);
		}
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_OrderWindowList: {
		const uint32_t *w = (const uint32_t *)buf;
		uint32_t size = h->msgh_size;
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || size < 0x2c || size > 0x302c || len != size) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		uint32_t n = w[8];
		if (n > SLS_LIST_MAX || n * 4 + 0x2c > size) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		uint32_t m = w[9 + n];
		if (m > SLS_LIST_MAX || (size - n * 4) < m * 4 + 0x2c) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		uint32_t k = w[10 + n + m];
		if (k > SLS_LIST_MAX || size != (n + m + k) * 4 + 0x2c) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const uint32_t *ids = w + 9, *ops = w + 10 + n, *rel = w + 11 + n + m;
		for (uint32_t i = 0; i < n; i++)                       /* operation and relative window per index (inferred) */
			if (holds_rights(c, ids[i]) && m && k) ws_order_window(srv, ids[i], (int32_t)ops[i < m ? i : m - 1], rel[i < k ? i : k - 1]);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_ConnectionGetPIDAndVersion: {
		if (!simple_ok(h, len, sizeof(sls_wid_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		conn *t = conn_by_id(((const sls_wid_req *)buf)->wid);
		if (!t) return reply_simple(c->fd, h, 0x3ea);          /* unknown connection: 1002 */
		sls_pid_version_rep r; memset(&r, 0, sizeof r);
		{ mach_msg_header_t rh; fill_reply_header(&rh, h, sizeof r, 0); memcpy(&r.h, &rh, sizeof rh); }
		r.ndr = WS_NDR; r.value = (uint64_t)(uint32_t)t->pid;   /* the original copies 8 bytes of connection state; layout inferred */
		struct iovec v = { &r, sizeof r };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_WarpCursorPosition: {
		if (!simple_ok(h, len, sizeof(sls_warp_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_warp_req *q = (const void *)buf;
		ws_server_warp_cursor(srv, q->x, q->y);                /* the original warps first, then validates the interval */
		float iv = bits2f(q->interval_bits);
		if (!(iv >= 0.0f && iv <= 10.0f)) return reply_simple(c->fd, h, 0x3ef);     /* "Invalid interval": 1007 */
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_SetWindowBackgroundBlurRadius: {                       /* wid@0x20, radius@0x24 (clamped to 60), flag byte@0x28, float@0x2c; always 0 */
		if (!simple_ok(h, len, 0x30)) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		uint32_t wid = rd32(buf, 0x20), rad = rd32(buf, 0x24); float amt = bits2f(rd32(buf, 0x2c));
		if (holds_rights(c, wid)) ws_set_window_blur(srv, wid, rad > 60 ? 60 : (int)rad, buf[0x28] != 0, amt);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetWindowTags: {                                        /* wid@0x20; reply 0x2c with the 64-bit tags@0x24 (0 for an unknown window) */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		uint8_t m[0x2c]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 0);
		memcpy(m + 0x18, &WS_NDR, 8);
		uint64_t t = ws_window_tags(srv, rd32(buf, 0x20)); memcpy(m + 0x24, &t, 8);
		struct iovec v = { m, sizeof m };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_GetWindowEventMask: {
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		int mask = 0;
		if (ws_window_event_mask(srv, rd32(buf, 0x20), &mask)) return sls_ext_dispatch(c, buf, len);     /* unknown window: what the real server answers (recorded) */
		return reply_value(c->fd, h, mask);
	}
	case SLS_MSG_SetWindowEventMask: {
		if (!simple_ok(h, len, sizeof(sls_eventmask_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_eventmask_req *q = (const void *)buf;
		if (holds_rights(c, q->wid)) ws_set_window_event_mask(srv, q->wid, q->level);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetCursorScale: {
		if (!simple_ok(h, len, sizeof(sls_header_only_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		float one = 1.0f; uint32_t bits; memcpy(&bits, &one, 4);
		return reply_value(c->fd, h, (int32_t)bits);
	}
	case SLS_MSG_ModifyKeyFocus: {
		if (!c->registered) return reply_simple(c->fd, h, -600);                    /* no process record: procNotFound */
		if (!simple_ok(h, len, sizeof(sls_two_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_two_req *q = (const void *)buf;
		if ((uint8_t)q->a == 1) { ws_keyfocus_release(srv, c->id, 0); return reply_simple(c->fd, h, 0); }
		return reply_simple(c->fd, h, ws_keyfocus_steal(srv, c->id, q->b, 0, NULL));
	}
	case SLS_MSG_StealKeyFocusReturningID: {
		if (!c->registered) return reply_simple(c->fd, h, -600);                    /* no process record: procNotFound */
		if (!simple_ok(h, len, sizeof(sls_terminate_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		int id = 0, rc = ws_keyfocus_steal(srv, c->id, (int)((const sls_terminate_req *)buf)->wid, 1, &id);
		return rc ? reply_simple(c->fd, h, rc) : reply_value(c->fd, h, id);          /* success replies are 0x28 long with the id */
	}
	case SLS_MSG_ReleaseKeyFocusWithID: {
		if (!c->registered) return reply_simple(c->fd, h, -600);                    /* no process record: procNotFound */
		if (!simple_ok(h, len, sizeof(sls_terminate_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		return reply_simple(c->fd, h, ws_keyfocus_release(srv, c->id, (int)((const sls_terminate_req *)buf)->wid));
	}
	case SLS_MSG_GetKeyFocusProcess: {
		if (!simple_ok(h, len, sizeof(sls_header_only_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		int dflt = 0; uint32_t holder = ws_keyfocus_holder(srv, &dflt);
		if (!holder) return reply_simple(c->fd, h, -600);                       /* procNotFound */
		sls_keyproc_reply r; memset(&r, 0, sizeof r);
		fill_reply_header(&r.h, h, sizeof r, 0);
		r.ndr = WS_NDR; r.psn_lo = holder; r.is_default = dflt;                   /* no PSNs here: the connection id stands in for the low word */
		struct iovec v = { &r, sizeof r };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_GetTypingFocusProcess: {
		if (!simple_ok(h, len, sizeof(sls_header_only_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		conn *t = conn_by_id(ws_keyfocus_holder(srv, NULL));
		return t ? reply_value(c->fd, h, t->pid) : reply_simple(c->fd, h, -600);
	}
	case SLS_MSG_HideCursor: case SLS_MSG_ObscureCursor: case SLS_MSG_RevealCursor: {
		if (!simple_ok(h, len, sizeof(sls_terminate_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		uint32_t cid = ((const sls_terminate_req *)buf)->wid;
		int known = conn_by_id(cid) != NULL;
		if (h->msgh_id == SLS_MSG_RevealCursor) { if (known) ws_cursor_reveal(srv, cid); return reply_simple(c->fd, h, 0); }
		if (!known) return reply_simple(c->fd, h, h->msgh_id == SLS_MSG_HideCursor ? 1000 : 1001);
		if (h->msgh_id == SLS_MSG_HideCursor) ws_cursor_hide(srv, cid); else ws_cursor_obscure(srv, cid);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_ShowCursor: {
		if (!simple_ok(h, len, sizeof(sls_two_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_two_req *q = (const void *)buf;
		if (conn_by_id((uint32_t)q->a)) ws_cursor_unhide(srv, (uint32_t)q->a, (uint8_t)q->b);
		return reply_simple(c->fd, h, 0);                                        /* always 0, even for an unknown connection */
	}
	case SLS_MSG_RegisterCursorWithData: return do_cursor_register(c, buf, len);
	case SLS_MSG_SetRegisteredCursor: case SLS_MSG_IsCursorRegistered: case SLS_MSG_GetRegisteredCursorDataSize: case SLS_MSG_GetRegisteredCursorData: {
		char name[SLS_CURSOR_NAME_MAX + 1];
		if (!cursor_name(h, buf, len, 0, name)) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		cursor_entry *e = cursor_find(c->id, name);
		if (h->msgh_id == SLS_MSG_IsCursorRegistered) { sls_value_reply r; memset(&r, 0, sizeof r); fill_reply_header(&r.h, h, sizeof r, 0); r.ndr = WS_NDR; r.value = e != NULL; struct iovec v = { &r, sizeof r }; return ws_ipc_send(c->fd, &v, 1, NULL, 0); }
		if (!e) return reply_simple(c->fd, h, 0x3ef);                    /* 1007 */
		if (h->msgh_id == SLS_MSG_SetRegisteredCursor) { cursor_apply(e); return reply_simple(c->fd, h, 0); }
		if (h->msgh_id == SLS_MSG_GetRegisteredCursorDataSize) return reply_value(c->fd, h, (int32_t)(e->cols * e->rows * e->frames * 4));
		return do_cursor_get_data(c, h, e);
	}
	case SLS_MSG_RemoveRegisteredCursor: {
		char name[SLS_CURSOR_NAME_MAX + 1];
		if (!cursor_name(h, buf, len, 4, name)) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		if (!name[0] || !strncmp(name, "com.apple.coregraphics.", 0x17)) return reply_simple(c->fd, h, 1000);   /* the system's own names are not removable */
		uint32_t n; memcpy(&n, buf + 0x24, 4);
		int global = buf[0x28 + ((n + 3) & ~3u)] != 0;
		for (int i = 0; i < MAXCURSORS; i++) if (cursors[i].used && !strcmp(cursors[i].name, name) && ((!cursors[i].global && cursors[i].owner == c->id) || (global && cursors[i].global))) cursor_free(&cursors[i]);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_AddSurface: {
		if (!simple_ok(h, len, sizeof(sls_wid_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		uint32_t wid = ((const sls_wid_req *)buf)->wid;
		if (!holds_rights(c, wid)) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		surf *sf = NULL;
		{ int ns = 0; for (int i = 0; i < MAXSURF; i++) if (surfs[i].used && surfs[i].owner == c->id) ns++; if (ns >= 128) return reply_simple(c->fd, h, CGS_ERROR_FAILURE); }       /* per-connection surface limit */
		for (int i = 0; i < MAXSURF && !sf; i++) if (!surfs[i].used) sf = &surfs[i];
		if (!sf) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		memset(sf, 0, sizeof *sf); sf->used = 1; sf->wid = wid; sf->sid = next_sid++; sf->owner = c->id; sf->alpha = 1.0f;
		return reply_value(c->fd, h, (int32_t)sf->sid);
	}
	case SLS_MSG_RemoveSurface: {
		if (!simple_ok(h, len, sizeof(sls_surface_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_surface_req *q = (const void *)buf;
		return reply_simple(c->fd, h, wsd_remove_surface(c, q->wid, (uint32_t)q->level));
	}
	case SLS_MSG_BindSurface: {
		if (!simple_ok(h, len, sizeof(sls_bind_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_bind_req *q = (const void *)buf;
		return reply_simple(c->fd, h, wsd_bind_surface(c, q->wid, q->sid, q->kind, q->a, q->b));
	}
	case SLS_MSG_GetSurfaceBinding: {
		if (!simple_ok(h, len, sizeof(sls_surface_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		const sls_surface_req *q = (const void *)buf;
		surf *sf = surf_find(q->wid, (uint32_t)q->level);
		if (!sf) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		sls_binding_reply r; memset(&r, 0, sizeof r);
		fill_reply_header(&r.h, h, sizeof r, 0);
		r.ndr = WS_NDR; r.kind = sf->kind; r.a = sf->a; r.b = sf->b;
		struct iovec v = { &r, sizeof r };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_MoveSurface: {                                                    /* wid@0x20, surface@0x24, x@0x28, y@0x2c (integers), size 0x30; write access needed; always 0 */
		if (!simple_ok(h, len, 0x30)) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		surf *sf = surf_find(rd32(buf, 0x20), rd32(buf, 0x24));
		if (sf && holds_rights(c, sf->wid)) { sf->ox = (int32_t)rd32(buf, 0x28); sf->oy = (int32_t)rd32(buf, 0x2c); }
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_OrderSurface: {                                                   /* wid@0x20, surface@0x24, mode@0x28, relative surface@0x2c, size 0x30; the stacking of a window's surfaces is not kept; always 0 */
		if (!simple_ok(h, len, 0x30)) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetSurfaceBounds: {                                               /* wid@0x20, surface@0x24, size 0x28; reply 0x34: x y w h (integers) @0x24; 1000 unknown window, 1001 unknown surface (zeros) */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		uint32_t wid = rd32(buf, 0x20); ws_rect f;
		if (ws_window_frame(srv, wid, &f)) return reply_simple(c->fd, h, 1000);
		surf *sf = surf_find(wid, rd32(buf, 0x24));
		if (!sf) return reply_simple(c->fd, h, 0x3e9);
		uint8_t r[0x34]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, 8); wr32(r, 0x24, (uint32_t)sf->ox); wr32(r, 0x28, (uint32_t)sf->oy); wr32(r, 0x2c, (uint32_t)f.w); wr32(r, 0x30, (uint32_t)f.h);
		struct iovec v = { r, sizeof r };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_SetSurfaceOpacity: {                                              /* wid@0x20, surface@0x24, opaque (byte)@0x28, size 0x2c; always 0 */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		surf *sf = surf_find(rd32(buf, 0x20), rd32(buf, 0x24));
		if (sf && holds_rights(c, sf->wid)) sf->opaque = buf[0x28] != 0;
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetSurfaceOpacity: {                                              /* wid@0x20, surface@0x24, size 0x28; reply 0x28: the flag byte@0x24; 1000 unknown window, 1001 unknown surface */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		uint32_t wid = rd32(buf, 0x20); ws_rect f;
		if (ws_window_frame(srv, wid, &f)) return reply_simple(c->fd, h, 1000);
		surf *sf = surf_find(wid, rd32(buf, 0x24));
		if (!sf) return reply_simple(c->fd, h, 0x3e9);
		uint8_t r[0x28]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, 8); r[0x24] = sf->opaque;
		struct iovec v = { r, sizeof r };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_SetSurfaceListAlpha: {                                            /* wid@0x20, count@0x24 (<= 0x400), surface ids@0x28, alpha float after them; size 4 * count + 0x2c; 1000 without rights, 1001 for no surfaces or an unknown one */
		uint32_t n = h->msgh_size >= 0x2c ? rd32(buf, 0x24) : 0;
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x2c || n > 0x400 || h->msgh_size != n * 4 + 0x2c) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
		uint32_t wid = rd32(buf, 0x20); float a; memcpy(&a, buf + 0x28 + 4 * n, 4);
		if (!ws_window_exists(srv, wid) || !holds_rights(c, wid)) return reply_simple(c->fd, h, 1000);
		if (n == 0) return reply_simple(c->fd, h, 0x3e9);
		int bad = 0; if (a != a) a = 0; a = a > 1 ? 1 : a < 0 ? 0 : a;
		for (uint32_t i = 0; i < n; i++) { surf *sf = surf_find(wid, rd32(buf, 0x28 + 4 * i)); if (sf) sf->alpha = a; else bad = 1; }
		return reply_simple(c->fd, h, bad ? 0x3e9 : 0);
	}
	default: return sls_ext_dispatch(c, buf, len);
	}
}

/* FlushSurface: the client finished drawing; the bound buffer is ready to compose */
static int do_flush_surface(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != sizeof(sls_flush_surface_req) || len < h->msgh_size)
		return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	sls_flush_surface_req q; memcpy(&q, buf, sizeof q);
	if (q.body.msgh_descriptor_count != 1) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	if (q.region.type != MACH_MSG_OOL_DESCRIPTOR || q.region.size != q.region_size || len != sizeof q + q.region.size)
		return reply_simple(c->fd, h, MIG_TYPE_ERROR);
	if (!holds_rights(c, q.wid)) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
	surf *sf = surf_find(q.wid, q.sid);
	if (!sf) return reply_simple(c->fd, h, CGS_ERROR_ILLEGAL_ARGUMENT);
	ws_rect bb = { 0, 0, 0, 0 };
	int has_region = 0;
	if (q.region.size) {                                       /* an empty region means the whole surface */
		ws_rect *r; int n;
		if (ws_region_parse(buf + sizeof q, q.region.size, &r, &n, &bb)) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
		free(r);
		has_region = 1;
	}
	if (sf->kind == SLS_BIND_CONTEXT) ws_window_flush_rect(srv, sf->wid, has_region ? &bb : NULL);   /* copies and marks only this rectangle */
	return reply_simple(c->fd, h, 0);
}

/* wsbsd private: register a shared buffer received as file descriptors */
static int do_buffer_import(conn *c, const uint8_t *buf, size_t len, int *fds, int nfds)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	int rc = 0, used[WS_IPC_MAX_FDS] = { 0 };
	wsx_buffer_import_req q;
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != sizeof q || len != sizeof q) { rc = MIG_BAD_ARGUMENTS; goto fail; }
	memcpy(&q, buf, sizeof q);
	if (q.nplanes != 1 || q.body.msgh_descriptor_count != (uint32_t)q.nplanes || nfds < 1) { rc = MIG_BAD_ARGUMENTS; goto fail; }
	if (q.plane[0].type != MACH_MSG_PORT_DESCRIPTOR || q.plane[0].disposition != MACH_MSG_TYPE_MOVE_SEND || q.plane[0].name < 1 || (int)q.plane[0].name > nfds) { rc = MIG_TYPE_ERROR; goto fail; }
	int bpp = ws_buffer_bytes_per_pixel(q.fourcc);
	if (!bpp || q.width <= 0 || q.height <= 0 || q.width > 16384 || q.height > 16384 || (q.kind != WS_BUF_SHM && q.kind != WS_BUF_DMABUF) ||
	    q.stride[0] < (uint32_t)(q.width * bpp)) { rc = CGS_ERROR_ILLEGAL_ARGUMENT; goto fail; }
	{ int nb = 0; double bytes = 0;                                          /* per-connection limits: 64 buffers, 1 GiB of them */
	  for (int i = 0; i < MAXBUF; i++) if (bufs[i].id && bufs[i].owner == c->id) { nb++; bytes += (double)bufs[i].stride[0] * bufs[i].h; }
	  if (nb >= 64 || bytes + (double)q.stride[0] * q.height > 1024.0 * 1024 * 1024) { rc = CGS_ERROR_FAILURE; goto fail; } }
	ws_buffer *b = NULL;
	for (int i = 0; i < MAXBUF && !b; i++) if (!bufs[i].id) b = &bufs[i];
	if (!b) { rc = CGS_ERROR_FAILURE; goto fail; }
	ws_buffer_init(b);
	b->kind = q.kind; b->w = q.width; b->h = q.height; b->fourcc = q.fourcc; b->nplanes = 1;
	b->stride[0] = q.stride[0]; b->offset[0] = q.offset[0]; b->modifier = q.modifier;
	b->fd[0] = fds[q.plane[0].name - 1]; used[q.plane[0].name - 1] = 1;
	ws_buffer_map(b);                                          /* a linear buffer gets a CPU view (the software path and the GL upload path) */
	b->id = next_buf++;
#ifdef WS_GL
	if (glc && b->kind == WS_BUF_DMABUF && glc_import_buffer(glc, b) == 0) {      /* hardware path: EGLImage from the dma-buf */
		b->egl_image = b;                                      /* marker: the compositor holds the import */
		if (!b->cpu && (b->cpu = calloc(1, sizeof *b->cpu))) { b->cpu->w = b->w; b->cpu->h = b->h; b->cpu->stride = b->stride[0]; }   /* a GPU-only buffer: geometry, no pixels */
	}
#endif
	if (!b->cpu) { ws_buffer_close(b); memset(b, 0, sizeof *b); rc = CGS_ERROR_FAILURE; goto fail; }   /* tiled dma-buf and no GL import: unusable */
	b->owner = c->id;
	for (int i = 0; i < nfds; i++) if (!used[i]) close(fds[i]);
	return reply_value(c->fd, h, (int32_t)b->id);
fail:
	for (int i = 0; i < nfds; i++) if (!used[i]) close(fds[i]);
	return reply_simple(c->fd, h, rc);
}

/* PostEventRecord: decode the event record and synthesise the input it describes */
static int do_post_event(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len < sizeof(sls_post_event_head) || len != h->msgh_size || h->msgh_size > 0x4038)
		return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	sls_post_event_head hd; memcpy(&hd, buf, sizeof hd);
	uint32_t n = hd.record_len;
	if (n > 0x4000 || n > h->msgh_size - 0x38 || h->msgh_size != ((n + 3) & ~3u) + 0x38) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	if (n == 0) return reply_simple(c->fd, h, CGS_ERROR_ILLEGAL_ARGUMENT);          /* nothing to decode: 1001 */
	ws_evrec rec;
	if (ws_evrec_parse(buf + 0x38, n, &rec)) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);   /* undecodable record: 1000 */
	int type = ws_evrec_type(&rec);
	float fx = 0, fy = 0;
	ws_evrec_location(&rec, &fx, &fy);
	int x = (int)floorf(fx), y = (int)floorf(fy), b = ws_server_buttons(srv);
	switch (type) {                                                    /* CGEventType numbers */
	case 1: b |= 1; goto mouse;  case 2: b &= ~1; goto mouse;
	case 3: b |= 2; goto mouse;  case 4: b &= ~2; goto mouse;
	case 25: b |= 4; goto mouse; case 26: b &= ~4; goto mouse;
	case 5: case 6: case 7: case 27:
	mouse:
		ws_server_mouse(srv, x, y, b);
		break;
	case 12: ws_server_flags(srv, ws_evrec_flags(&rec)); break;          /* flagsChanged */
	case 22: {                                                          /* scroll wheel: point deltas (fields 96, 97), else line deltas (11, 12) x 10 */
		const ws_evfield *p1 = ws_evrec_find(&rec, 96), *p2 = ws_evrec_find(&rec, 97), *l1 = ws_evrec_find(&rec, 11), *l2 = ws_evrec_find(&rec, 12), *ic = ws_evrec_find(&rec, 88);
		int dy = p1 ? (int)p1->v[0] : l1 ? (int)l1->v[0] * 10 : 0, dx = p2 ? (int)p2->v[0] : l2 ? (int)l2->v[0] * 10 : 0;
		ws_server_scroll(srv, x, y, dx, dy, ic ? (int)ic->v[0] : 0);
		break;
	}
	case 10: case 11: {
		int kc = ws_evrec_keycode(&rec);
		if (kc >= 0) ws_server_key(srv, kc, type == 10);
		break;
	}
	default: break;                                                    /* flags-changed, scroll, ...: accepted, not delivered yet */
	}
	return reply_simple(c->fd, h, 0);
}


/* PostFilteredEventTapData (32025), ...Sync (32026) and ...OOL (32027): what SLEventPostToPid / SLEventPostToPSN send (style 2 = "to the process only"). Request (decompiled
 * __XPostFilteredEventTapData): style@0x20, tap id / PSN low@0x24, sequence / PSN high@0x28, u32@0x2c, data length n@0x30 (<= 0x4000), data@0x34, size pad4(n) + 0x34.
 * The data is a run of events: u32 token (0), u32 length, the event as CGEventCreateData makes it. SLEventPostToPid passes {1, pid}: a PSN whose low word is 1 and
 * whose high word is the pid. Delivery to the process: the key / mouse / flags / scroll event goes to the process's frontmost ordered-in window. Anyone may post
 * (the real server checks that the sender may synthesize events). */
static conn *process_for_psn(uint32_t lo, uint32_t hi)
{
	for (int i = 0; i < MAXCONN; i++) {
		conn *t = &conns[i];
		if (t->fd < 0) continue;
		if (lo == 1 && t->pid && (uint32_t)t->pid == hi) return t;            /* the pid-style PSN */
		if (t->registered && t->psn_lo == lo && t->psn_hi == hi) return t;
	}
	return NULL;
}

static int deliver_to_process(conn *t, const uint8_t *rec, size_t n)
{
	ws_evrec r;
	if (ws_evrec_parse(rec, n, &r)) return -1;
	ws_wid ids[1];
	if (ws_list_windows(srv, t->id, 1, ids, 1) < 1) return -1;                  /* no window to receive it */
	ws_rect f; if (ws_window_frame(srv, ids[0], &f)) return -1;
	int type = ws_evrec_type(&r);
	float fx = 0, fy = 0; ws_evrec_location(&r, &fx, &fy);
	int x = (int)floorf(fx) - f.x, y = (int)floorf(fy) - f.y;
	ws_event e; memset(&e, 0, sizeof e);
	e.x = x; e.y = y; e.flags = ws_evrec_flags(&r);
	switch (type) {
	case 1: case 3: case 25: e.type = WS_EV_MOUSE_DOWN; e.buttons = type == 1 ? 1 : type == 3 ? 2 : 4; break;
	case 2: case 4: case 26: e.type = WS_EV_MOUSE_UP; break;
	case 5: case 6: case 7: case 27: e.type = WS_EV_MOUSE_MOVE; break;
	case 10: case 11: { int kc = ws_evrec_keycode(&r); if (kc < 0) return -1; e.type = type == 10 ? WS_EV_KEY_DOWN : WS_EV_KEY_UP; e.key = kc; break; }
	case 12: e.type = WS_EV_FLAGS; break;
	case 22: {
		const ws_evfield *p1 = ws_evrec_find(&r, 96), *p2 = ws_evrec_find(&r, 97), *l1 = ws_evrec_find(&r, 11), *l2 = ws_evrec_find(&r, 12), *ic = ws_evrec_find(&r, 88);
		e.type = WS_EV_SCROLL; e.dy = p1 ? (int)p1->v[0] : l1 ? (int)l1->v[0] * 10 : 0; e.dx = p2 ? (int)p2->v[0] : l2 ? (int)l2->v[0] * 10 : 0; e.continuous = ic ? (int)ic->v[0] : 0;
		break;
	}
	default: return -1;
	}
	return ws_window_post(srv, ids[0], &e);
}

/* PostNotificationToConnection (30123) and PostBroadcastNotification (30122), decompiled __X routines: the notification is pushed to the connection's event channel.
 * ToConnection: type@0x20, n@0x24 (<= 0x4000), data@0x28, then the target connection id (u32 after the padded data); size pad4(n) + 0x2c.
 * Broadcast: type@0x20, n@0x24, data@0x28; size pad4(n) + 0x28; delivered to every connection whose notification interests (SetConnectionNotifyInterests) list the type. Always 0. */
static void push_notification(conn *t, uint32_t type, const uint8_t *data, uint32_t n)
{
	if (!t || t->efd < 0) return;
	wsx_notify_msg m; memset(&m, 0, sizeof m);
	m.h.msgh_bits = MACH_MSG_TYPE_MOVE_SEND_ONCE; m.h.msgh_size = sizeof m; m.h.msgh_id = WSX_NOTIFY_PUSH;
	m.ndr = WS_NDR; m.type = type; m.len = n > sizeof m.data ? (uint32_t)sizeof m.data : n; memcpy(m.data, data, m.len);
	ws_ipc_send(t->efd, &(struct iovec){ &m, sizeof m }, 1, NULL, 0);
}
void wsd_push_notification(uint32_t owner, uint32_t type, const uint8_t *data, uint32_t n) { push_notification(conn_by_id(owner), type, data, n); }
static int do_post_notification(conn *c, const uint8_t *buf, size_t len, int broadcast)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	size_t fixed = broadcast ? 0x28 : 0x2c;
	if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < fixed || h->msgh_size > 0x4000 + fixed + 4) return reply_simple(c->fd, h, -304);
	uint32_t n = rd32(buf, 0x24), P = (n + 3) & ~3u;
	if (n > 0x4000 || h->msgh_size != P + fixed) return reply_simple(c->fd, h, -304);
	uint32_t type = rd32(buf, 0x20);
	if (broadcast) {
		for (int i = 0; i < MAXCONN; i++) {
			conn *t = &conns[i];
			if (t->fd < 0) continue;
			for (uint32_t k = 0; k < t->notify_n; k++) if (t->notify[k] == type) { push_notification(t, type, buf + 0x28, n); break; }
		}
	} else {
		push_notification(wsd_conn_by_id(rd32(buf, 0x28 + P)), type, buf + 0x28, n);
	}
	return reply_simple(c->fd, h, 0);
}

/* PostEventRecordTo (30120): request = header, NDR, PSN (hi@0x20, lo@0x24), n@0x28 (<= 0x4000), the record@0x2c, size pad4(n) + 0x2c. -304 for a bad size, -600 when no process has that PSN. */
static int do_post_event_record_to(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x2c || h->msgh_size > 0x402c) return reply_simple(c->fd, h, -304);
	uint32_t n = rd32(buf, 0x28);
	if (n > 0x4000 || n > h->msgh_size - 0x2c || h->msgh_size != ((n + 3) & ~3u) + 0x2c) return reply_simple(c->fd, h, -304);
	conn *t = process_for_psn(rd32(buf, 0x24), rd32(buf, 0x20));
	if (!t) return reply_simple(c->fd, h, -600);
	if (n) deliver_to_process(t, buf + 0x2c, n);
	return reply_simple(c->fd, h, 0);
}

static int do_post_tap_data(conn *c, const uint8_t *buf, size_t len, int ool)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	uint32_t style, a, b; const uint8_t *data; size_t n;
	if (!ool) {
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != h->msgh_size || h->msgh_size < 0x34 || h->msgh_size > 0x4034) return reply_simple(c->fd, h, -304);
		n = rd32(buf, 0x30);
		if (n > 0x4000 || n > h->msgh_size - 0x34 || h->msgh_size != ((n + 3) & ~(size_t)3) + 0x34) return reply_simple(c->fd, h, -304);
		style = rd32(buf, 0x20); a = rd32(buf, 0x24); b = rd32(buf, 0x28); data = buf + 0x34;
	} else {                                                                      /* one OOL descriptor (payload appended to the datagram), size 0x48 */
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x48 || len < 0x48 || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
		if (buf[0x27] != 1 || rd32(buf, 0x28) != rd32(buf, 0x44)) return reply_simple(c->fd, h, -300);
		n = rd32(buf, 0x28);
		if (len != 0x48 + n) return reply_simple(c->fd, h, -300);
		style = rd32(buf, 0x34); a = rd32(buf, 0x38); b = rd32(buf, 0x3c); data = buf + 0x48;
	}
	if (style == 2) {
		conn *t = process_for_psn(a, b);
		size_t i = 0;
		while (t && n - i > 7) {
			uint32_t tok = rd32(data, i), l = rd32(data, i + 4);
			if (tok != 0 || l > n - i - 8) break;
			deliver_to_process(t, data + i + 8, l);
			i += 8 + l;
		}
	}
	return reply_simple(c->fd, h, 0);
}

static int do_new_connection(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len < sizeof(sls_new_connection_head) || len != h->msgh_size)
		return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	sls_new_connection_head hd;
	memcpy(&hd, buf, sizeof hd);
	if (hd.body.msgh_descriptor_count != 2 || h->msgh_size < 0x54 || h->msgh_size > 0x454) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	if (hd.port_a.disposition != MACH_MSG_TYPE_MOVE_SEND || hd.port_a.type != MACH_MSG_PORT_DESCRIPTOR ||
	    hd.port_b.disposition != MACH_MSG_TYPE_MOVE_SEND || hd.port_b.type != MACH_MSG_PORT_DESCRIPTOR)
		return reply_simple(c->fd, h, MIG_TYPE_ERROR);
	uint32_t n = hd.name_len, pad = (n + 3) & ~3u;
	if (n > 0x400 || h->msgh_size - 0x54 < n || h->msgh_size != pad + 0x54) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	if (c->handshaken) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
	int sv[2];
	if (ws_ipc_socketpair(sv)) return reply_simple(c->fd, h, CGS_ERROR_FAILURE);
	fcntl(sv[0], F_SETFL, fcntl(sv[0], F_GETFL) | O_NONBLOCK);
	memset(c->app, 0, sizeof c->app);
	memcpy(c->app, buf + sizeof hd, n < sizeof c->app - 1 ? n : sizeof c->app - 1);
	c->efd = sv[0]; c->handshaken = 1; c->pid = peer_pid(c->fd);
	sls_new_connection_rep r; memset(&r, 0, sizeof r);
	{ mach_msg_header_t rh; fill_reply_header(&rh, h, sizeof r, 1); memcpy(&r.h, &rh, sizeof rh); }
	r.body.msgh_descriptor_count = 2;
	r.port1 = (mach_msg_port_descriptor_t){ .name = 0, .disposition = 20 /* MAKE_SEND */, .type = MACH_MSG_PORT_DESCRIPTOR };   /* the connection port: this socket */
	r.port2 = (mach_msg_port_descriptor_t){ .name = 1, .disposition = MACH_MSG_TYPE_MOVE_SEND, .type = MACH_MSG_PORT_DESCRIPTOR }; /* event channel */
	r.ndr = WS_NDR; r.connection_id = c->id;
	struct iovec v = { &r, sizeof r };
	int rc = ws_ipc_send(c->fd, &v, 1, &sv[1], 1);
	close(sv[1]);
	return rc;
}

static int do_buffer_release(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (!simple_ok(h, len, sizeof(wsx_buffer_release_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	ws_buffer *b = buf_by_id((uint32_t)((const wsx_buffer_release_req *)buf)->level);
	if (!b || b->owner != c->id) return reply_simple(c->fd, h, CGS_ERROR_ILLEGAL_ARGUMENT);
	buf_release(b);
	return reply_simple(c->fd, h, 0);
}

/* ---- private wsbsd extension (ids 39001..) ---- */
static int do_private(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (!simple_ok(h, len, sizeof(wsx_req))) return reply_simple(c->fd, h, MIG_BAD_ARGUMENTS);
	wsx_req q; memcpy(&q, buf, sizeof q);
	wsx_rep r; memset(&r, 0, sizeof r);
	fill_reply_header(&r.h, h, sizeof r, 0);
	r.ndr = WS_NDR;
	int32_t *a = q.a;
	if (!test_mode && (h->msgh_id == WSX_SCREENSHOT || h->msgh_id == WSX_INJECT_MOUSE || h->msgh_id == WSX_INJECT_KEY || h->msgh_id == WSX_QUIT))
		return reply_mig_error(c->fd, h, MIG_BAD_ID);          /* a client must not write files, forge input or stop the server */
	switch (h->msgh_id) {
	case WSX_FLUSH: r.retcode = holds_rights(c, (uint32_t)a[0]) ? 0 : CGS_ERROR_FAILURE; if (!r.retcode) ws_window_damage(srv, (ws_wid)a[0], NULL); break;
	case WSX_SCREENSHOT:
		q.s[sizeof q.s - 1] = 0;
		render_frame(screen, !(a[0] & 1));                       /* a[0] bit 0: leave the cursor out */
		r.retcode = ws_write_ppm(screen, q.s) ? CGS_ERROR_FAILURE : 0;
		break;
	case WSX_INJECT_MOUSE: ws_server_mouse(srv, a[0], a[1], a[2]); break;
	case WSX_INJECT_KEY: ws_server_key(srv, a[0], a[1]); break;
	case WSX_NEXT_EVENT: {
		ws_event e = { 0 };
		ws_next_event(srv, (ws_wid)a[0], &e);
		r.a[0] = e.type; r.a[1] = (int32_t)e.wid; r.a[2] = e.x; r.a[3] = e.y; r.a[4] = e.buttons; r.a[5] = e.key;
		break;
	}
	case WSX_GET_CURSOR: ws_cursor_pos(srv, &r.a[0], &r.a[1]); break;
	case WSX_FIND_WINDOW: r.a[0] = (int32_t)ws_find_window(srv, a[0], a[1]); break;
	case WSX_SET_SHADOW: r.retcode = holds_rights(c, (uint32_t)a[0]) && !ws_set_window_shadow(srv, (ws_wid)a[0], a[1], a[2]) ? 0 : CGS_ERROR_FAILURE; break;
	case WSX_CAPTURE: {                                  /* pixels of the composed scene: a[0..3] rect (all zero: the whole screen), a[4] window id (its frame, 0: none), a[5] bit 0: with the cursor; the reply carries a shared memory descriptor of w*h BGRA pixels */
		int x = a[0], y = a[1], w = a[2], hh = a[3];
		if (a[4]) { ws_rect f; if (ws_window_frame(srv, (ws_wid)a[4], &f)) return reply_mig_error(c->fd, h, MIG_BAD_ID); x = (int)f.x; y = (int)f.y; w = (int)f.w; hh = (int)f.h; }
		else if (w <= 0 || hh <= 0) { x = 0; y = 0; w = wsd_screen_w; hh = wsd_screen_h; }
		if (w <= 0 || hh <= 0 || w > 16384 || hh > 16384) { r.retcode = CGS_ERROR_FAILURE; break; }
		render_frame(screen, a[5] & 1);
		int fd = -1; ws_surface *out = ws_surface_shm_anon(w, hh, &fd);
		if (!out) { r.retcode = CGS_ERROR_FAILURE; break; }
		ws_fill(out, (ws_rect){ 0, 0, w, hh }, 0, 0, 0, 0);
		ws_copy(out, 0, 0, screen, (ws_rect){ x, y, w, hh });
		r.a[0] = w; r.a[1] = hh;
		struct iovec cv = { &r, sizeof r };
		int rc = ws_ipc_send(c->fd, &cv, 1, &fd, 1);
		ws_surface_free(out); close(fd);
		return rc;
	}
	case WSX_QUIT: running = 0; break;
	case WSX_GET_CONNECTION_ID: r.a[0] = (int32_t)c->id; break;
	case WSX_GET_SCREEN: r.a[0] = wsd_screen_w; r.a[1] = wsd_screen_h; break;
	default: return reply_mig_error(c->fd, h, MIG_BAD_ID);
	}
	struct iovec v = { &r, sizeof r };
	return ws_ipc_send(c->fd, &v, 1, NULL, 0);
}

static int dispatch(conn *c, uint8_t *buf, size_t len, int *fds, int nfds)
{
	if (len < sizeof(mach_msg_header_t)) { for (int i = 0; i < nfds; i++) close(fds[i]); return -1; }
	mach_msg_header_t *h = (mach_msg_header_t *)buf;
	if (h->msgh_id == WSX_BUFFER_IMPORT && h->msgh_size <= len) { h->msgh_local_port = c->id; return do_buffer_import(c, buf, len, fds, nfds); }
	for (int i = 0; i < nfds; i++) close(fds[i]);                       /* every other request takes no descriptors */
	if (h->msgh_size < sizeof *h || h->msgh_size > len) return reply_mig_error(c->fd, h, MIG_BAD_ARGUMENTS);
	h->msgh_local_port = c->id;                                         /* the connection the request arrived on */
	if (h->msgh_id >= WSX_FLUSH && h->msgh_id <= WSX_CAPTURE) { dirty = 1; return do_private(c, buf, len); }
	if (h->msgh_id == SLS_MSG_CreateWindow) { dirty = 1; return do_create_window(c, buf, len); }
	if (h->msgh_id == SLS_MSG_NewConnectionPort) return do_new_connection(c, buf, len);
	if (h->msgh_id == SLS_MSG_FlushSurface) { dirty = 1; return do_flush_surface(c, buf, len); }
	if (h->msgh_id == WSX_BUFFER_RELEASE) return do_buffer_release(c, buf, len);
	if (h->msgh_id == SLS_MSG_PostEventRecord) { dirty = 1; return do_post_event(c, buf, len); }
	if (h->msgh_id == SLS_MSG_PostNotificationToConnection || h->msgh_id == SLS_MSG_PostBroadcastNotification) return do_post_notification(c, buf, len, h->msgh_id == SLS_MSG_PostBroadcastNotification);
	if (h->msgh_id == SLS_MSG_PostEventRecordTo) { dirty = 1; return do_post_event_record_to(c, buf, len); }
	if (h->msgh_id == SLS_MSG_PostFilteredEventTapData || h->msgh_id == SLS_MSG_PostFilteredEventTapDataSync) { dirty = 1; return do_post_tap_data(c, buf, len, 0); }
	if (h->msgh_id == SLS_MSG_PostFilteredEventTapDataOOL) { dirty = 1; return do_post_tap_data(c, buf, len, 1); }
	if ((h->msgh_id >= 29000 && h->msgh_id < 29042) || (h->msgh_id >= SLS_MSGID_BASE && h->msgh_id < SLS_MSGID_END) ||
	    (h->msgh_id >= 32000 && h->msgh_id < 32074) || (h->msgh_id >= 33000 && h->msgh_id < 33029) || (h->msgh_id >= 34000 && h->msgh_id < 34010)) {
		int rc = do_simple(c, buf, len);
		if (rc != -2) { dirty = 1; return rc; }
	}
	return reply_mig_error(c->fd, h, MIG_BAD_ID);                       /* known id we do not implement, or an unknown id */
}

conn *wsd_conn_by_psn(uint32_t hi, uint32_t lo) { for (int i = 0; i < MAXCONN; i++) if (conns[i].fd >= 0 && conns[i].registered && conns[i].psn_hi == hi && conns[i].psn_lo == lo) return &conns[i]; return NULL; }
int wsd_conns_for_pid(int pid, uint32_t *ids, int max) { int n = 0; for (int i = 0; i < MAXCONN && n < max; i++) if (conns[i].fd >= 0 && conns[i].pid == pid) ids[n++] = conns[i].id; return n; }
conn *wsd_conn_by_id(uint32_t id) { for (int i = 0; i < MAXCONN; i++) if (conns[i].fd >= 0 && conns[i].id == id) return &conns[i]; return NULL; }
static conn *conn_by_fd(int fd) { for (int i = 0; i < MAXCONN; i++) if (conns[i].fd == fd) return &conns[i]; return NULL; }

int main(int argc, char **argv)
{
	const char *path = getenv("WS_SOCKET") ? getenv("WS_SOCKET") : DEFAULT_SOCKET;
	int w = 1280, h = 800, sandbox = 0, vnc_port = 0, vnc_ls = -1; ws_input vin;
	int vnc_updates = 0, vnc_backlog_loops = 0; double vnc_render_ms = 0, vnc_report = 0;
	const char *backend = "headless", *card = "/dev/dri/card0", *renderer = "sw", *render_node = "/dev/dri/renderD128";
	for (int i = 1; i < argc; i++) {
		if (!strcmp(argv[i], "-s") && i + 1 < argc) path = argv[++i];
		else if (!strcmp(argv[i], "-g") && i + 1 < argc) sscanf(argv[++i], "%dx%d", &w, &h);
		else if (!strcmp(argv[i], "-b") && i + 1 < argc) backend = argv[++i];
		else if (!strcmp(argv[i], "-c") && i + 1 < argc) card = argv[++i];
		else if (!strcmp(argv[i], "-r") && i + 1 < argc) renderer = argv[++i];          /* sw | gl */
		else if (!strcmp(argv[i], "-n") && i + 1 < argc) render_node = argv[++i];
		else if (!strcmp(argv[i], "-t")) test_mode = 1;
		else if (!strcmp(argv[i], "-S")) sandbox = 1;
		else if (!strcmp(argv[i], "-V") && i + 1 < argc) vnc_port = atoi(argv[++i]);
	}
#ifdef WS_KMS
	ws_kms *kms = NULL;
	ws_evdev *input = NULL;
	int hw_cursor = 0;                          /* the cursor lives on the hardware plane: moving it needs no frame */
	uint64_t last_gen = ~0ULL; uint32_t last_cursor_serial = ~0u; int last_cx = -1, last_cy = -1;
	int vt_ok = 0, vt_active = 1;               /* console switching: vt_active is 0 while another VT is in front */
	if (!strcmp(backend, "kms")) {
		kms = ws_kms_open(card, &w, &h);
		if (!kms) { fprintf(stderr, "wsd: cannot open KMS device %s\n", card); return 1; }
		input = ws_evdev_open("/dev/input");
		if (!input || ws_evdev_count(input) == 0) fprintf(stderr, "wsd: warning: no evdev input devices readable\n");
	}
#else
	if (strcmp(backend, "headless")) { fprintf(stderr, "wsd: backend '%s' not built in (use gmake kms on FreeBSD)\n", backend); return 1; }
	(void)card;
#endif
	wsd_screen_w = w; wsd_screen_h = h;
	signal(SIGPIPE, SIG_IGN);
	srv = ws_server_new(w, h);
	screen = ws_surface_new(w, h);
	if (!srv || !screen) { fprintf(stderr, "wsd: out of memory\n"); return 1; }
	if (!strcmp(renderer, "gl")) {
#ifdef WS_GL
		glc = glc_create(render_node, w, h);
		if (glc) fprintf(stderr, "wsd: GL compositor: %s\n", glc_describe(glc));
		else fprintf(stderr, "wsd: GL compositor unavailable (EGL/GLES2 could not be initialised), using the software compositor\n");
#else
		fprintf(stderr, "wsd: built without GL (use gmake gl on FreeBSD), using the software compositor\n");
		(void)render_node;
#endif
	}
	for (int i = 0; i < MAXCONN; i++) { conns[i].fd = -1; conns[i].efd = -1; }
	ws_server_set_event_sink(srv, push_event, NULL);

	int ls = ws_ipc_listen(path);
	if (ls < 0) { perror("wsd: listen"); return 1; }
	int kq = kqueue();
	struct kevent ev;
	EV_SET(&ev, ls, EVFILT_READ, EV_ADD, 0, 0, NULL);
	if (kevent(kq, &ev, 1, NULL, 0, NULL) < 0) { perror("wsd: kevent"); return 1; }
#ifdef WS_KMS
	if (kms) {
		EV_SET(&ev, ws_kms_fd(kms), EVFILT_READ, EV_ADD, 0, 0, NULL);
		kevent(kq, &ev, 1, NULL, 0, NULL);
		for (int i = 0; input && i < ws_evdev_count(input); i++) {
			EV_SET(&ev, ws_evdev_fd(input, i), EVFILT_READ, EV_ADD, 0, 0, NULL);
			kevent(kq, &ev, 1, NULL, 0, NULL);
		}
		vt_ok = wsd_vt_setup() == 0;                              /* console switching: SIGUSR1 = leave, SIGUSR2 = come back */
		signal(SIGUSR1, SIG_IGN); signal(SIGUSR2, SIG_IGN); signal(SIGTERM, SIG_IGN); signal(SIGINT, SIG_IGN);
		int sigs[4] = { SIGUSR1, SIGUSR2, SIGTERM, SIGINT };
		for (int i = 0; i < 4; i++) { EV_SET(&ev, sigs[i], EVFILT_SIGNAL, EV_ADD, 0, 0, NULL); kevent(kq, &ev, 1, NULL, 0, NULL); }
		if (!vt_ok) fprintf(stderr, "wsd: not on a vt(4) console: no console switching (input stays grabbed)\n");
	}
#endif
	if (vnc_port > 0) {                                                            /* -V port: a VNC viewer on 127.0.0.1:port (WSD_VNC_PASSWORD, at most 8 characters, enables password authentication) */
		const char *pw = getenv("WSD_VNC_PASSWORD");
		vnc_ls = wsd_vnc_listen(vnc_port, pw);
		if (vnc_ls < 0) { perror("wsd: vnc listen"); return 1; }
		EV_SET(&ev, vnc_ls, EVFILT_READ, EV_ADD, 0, 0, NULL); kevent(kq, &ev, 1, NULL, 0, NULL);
		ws_input_init(&vin, w, h); vin.accel = 0;
		fprintf(stderr, "wsd: VNC on 127.0.0.1:%d%s\n", vnc_port, pw && *pw ? " (password)" : " (no password)");
	}
	fprintf(stderr, "wsd: %dx%d, backend %s, listening on %s\n", w, h, backend, path);
	if (sandbox) { if (wsd_sandbox_enter(ls, kq) == 0) fprintf(stderr, "wsd: capability mode\n"); else if (sandbox == 2) return 1; }

	while (running) {
		struct kevent out[16];
		struct timespec frame = { 0, 16 * 1000 * 1000 }, *to = NULL;
#ifdef WS_KMS
		if (kms && (ws_server_generation(srv) != last_gen || !hw_cursor)) to = &frame;
#else
		(void)frame;
#endif
		if (vnc_ls >= 0 && wsd_vnc_connected()) to = &frame;                      /* a viewer is attached: wake up to send updates */
		int n = kevent(kq, NULL, 0, out, 16, to);
		if (n < 0) { if (errno == EINTR) continue; perror("wsd: kevent"); break; }
		for (int i = 0; i < n; i++) {
			int fd = (int)out[i].ident;
			if (vnc_ls >= 0 && out[i].filter == EVFILT_READ && fd == vnc_ls) { int cfd = wsd_vnc_accept(); if (cfd >= 0) { EV_SET(&ev, cfd, EVFILT_READ, EV_ADD, 0, 0, NULL); kevent(kq, &ev, 1, NULL, 0, NULL); } continue; }
			if (vnc_ls >= 0 && out[i].filter == EVFILT_READ && fd == wsd_vnc_client_fd()) { wsd_vnc_read(srv, &vin, w, h, "wsd"); dirty = 1; continue; }
#ifdef WS_KMS
			if (out[i].filter == EVFILT_SIGNAL) {
				if (fd == SIGUSR1) { vt_active = 0; if (kms) ws_kms_pause(kms); wsd_vt_release_ack(); }
				else if (fd == SIGUSR2) { wsd_vt_acquire_ack(); if (kms && ws_kms_resume(kms) == 0) { vt_active = 1; last_gen = ~0ULL; last_cx = -1; last_cursor_serial = ~0u; hw_cursor = 0; dirty = 1; } }
				else running = 0;                                         /* SIGTERM / SIGINT: leave the loop, restore the console */
				continue;
			}
			if (kms && fd == ws_kms_fd(kms)) { ws_kms_handle_events(kms); continue; }
			if (input) {
				int idx = -1;
				for (int j = 0; j < ws_evdev_count(input); j++) if (ws_evdev_fd(input, j) == fd) idx = j;
				if (idx >= 0) {
					if (!vt_active) { if (ws_evdev_drain(input, idx) < 0) { EV_SET(&ev, fd, EVFILT_READ, EV_DELETE, 0, 0, NULL); kevent(kq, &ev, 1, NULL, 0, NULL); close(fd); } continue; }
					if (ws_evdev_dispatch(input, idx, srv, w, h) < 0) { EV_SET(&ev, fd, EVFILT_READ, EV_DELETE, 0, 0, NULL); kevent(kq, &ev, 1, NULL, 0, NULL); close(fd); }
					dirty = 1;
					continue;
				}
			}
#endif
			if (fd == ls) {
				int cfd = accept(ls, NULL, NULL);
				if (cfd < 0) continue;
				{ uid_t pu; gid_t pg; if (getpeereid(cfd, &pu, &pg) < 0 || (pu != geteuid() && pu != 0)) { close(cfd); continue; } }      /* defence in depth next to the socket's 0600 mode: only the server's user (or root) may connect */
				conn *slot = conn_by_fd(-1);
				if (!slot) { close(cfd); continue; }
				memset(slot, 0, sizeof *slot); slot->fd = cfd; slot->efd = -1; slot->id = next_conn++; slot->pid = 0;
				EV_SET(&ev, cfd, EVFILT_READ, EV_ADD, 0, 0, NULL);
				if (kevent(kq, &ev, 1, NULL, 0, NULL) < 0) { close(cfd); slot->fd = -1; }
				continue;
			}
			conn *c = conn_by_fd(fd);
			if (!c) continue;
			int fds[WS_IPC_MAX_FDS], nfds = 0;
			ssize_t len = ws_ipc_recv(fd, rbuf, sizeof rbuf, fds, &nfds);
			if (len <= 0 || dispatch(c, rbuf, (size_t)len, fds, nfds) < 0) {
				owner_cleanup(c->id);                                   /* its buffers and surfaces go too */
				ws_release_owner(srv, c->id);                           /* a client going away takes its windows with it */
				dirty = 1;
				if (c->efd >= 0) close(c->efd);
				close(fd); c->fd = -1; c->efd = -1;
			}
		}
		if (vnc_ls >= 0 && wsd_vnc_backlog()) wsd_vnc_flush();                      /* a slow viewer: keep draining its queue between other work */
		if (vnc_ls >= 0) {                                                         /* update the viewer when it asked and something moved or changed */
			int cx, cy; ws_cursor_pos(srv, &cx, &cy);
			uint64_t key = ws_server_generation(srv) * 1000003ULL + (uint64_t)cx * 4099 + (uint64_t)cy * 31 + ws_cursor_serial(srv);
			if (wsd_vnc_wants(key)) {
				struct timespec t0, t1; clock_gettime(CLOCK_MONOTONIC, &t0);
				render_frame(screen, 1); clock_gettime(CLOCK_MONOTONIC, &t1);
				wsd_vnc_update(screen, key);
				vnc_updates++; vnc_render_ms += (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6;
			}
			if (wsd_vnc_backlog()) vnc_backlog_loops++;
			if (vnc_updates || vnc_backlog_loops) { struct timespec tn; clock_gettime(CLOCK_MONOTONIC, &tn); double nowt = tn.tv_sec + tn.tv_nsec / 1e9;
				if (nowt - vnc_report >= 5.0) { if (vnc_report > 0 && vnc_updates) fprintf(stderr, "wsd: vnc %d updates in 5 s, compose %.1f ms each, viewer behind %d loops\n", vnc_updates, vnc_render_ms / vnc_updates, vnc_backlog_loops); vnc_report = nowt; vnc_updates = 0; vnc_render_ms = 0; vnc_backlog_loops = 0; } }
		}
#ifdef WS_KMS
		if (kms && vt_active) {
			int hx = 0, hy = 0, cx, cy;
			const ws_surface *cimg = ws_cursor_image(srv, &hx, &hy);
			ws_cursor_pos(srv, &cx, &cy);
			if (!hw_cursor && cimg && ws_kms_cursor_supported(kms) && ws_kms_cursor_set(kms, ws_cursor_visible(srv) ? cimg : NULL, hx, hy) == 0) { hw_cursor = 1; last_cursor_serial = ws_cursor_serial(srv); }
			if (hw_cursor) {
				if (ws_cursor_serial(srv) != last_cursor_serial) { if (ws_kms_cursor_set(kms, ws_cursor_visible(srv) ? cimg : NULL, hx, hy)) hw_cursor = 0; last_cursor_serial = ws_cursor_serial(srv); last_cx = -1; }     /* a new image or visibility: place it again */
				if (hw_cursor && (cx != last_cx || cy != last_cy)) ws_kms_cursor_move(kms, cx - hx, cy - hy);    /* no recomposition */
			}
			uint64_t gen = ws_server_generation(srv);
			int need = gen != last_gen || (!hw_cursor && (cx != last_cx || cy != last_cy || ws_cursor_serial(srv) != last_cursor_serial));
			if (need && ws_kms_present_ready(kms)) {
				render_frame(ws_kms_back(kms), !hw_cursor && ws_cursor_visible(srv));
				if (ws_kms_present(kms) == 0) { last_gen = gen; last_cx = cx; last_cy = cy; last_cursor_serial = ws_cursor_serial(srv); }
			} else if (hw_cursor) { last_cx = cx; last_cy = cy; }
		}
#endif
	}
#ifdef WS_KMS
	ws_evdev_close(input);
	ws_kms_close(kms);
	wsd_vt_restore();
#endif
#ifdef WS_GL
	glc_destroy(glc);
#endif
	unlink(path);
	ws_server_free(srv);
	ws_surface_free(screen);
	return 0;
}
