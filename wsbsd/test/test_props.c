/* Window properties, layer context binding and the ordered-in query, with the sizes, codes and layouts observed on the real server (lab/prop1.scen, win1.scen). */
#include "ws_client.h"
#include "ws_evrec.h"
#include "ws_ipc.h"
#include "sls_wire.h"
#include "ws_region.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)
static void w32(uint8_t *b, size_t o, uint32_t v) { memcpy(b + o, &v, 4); }
static uint32_t r32(const uint8_t *b, size_t o) { uint32_t v; memcpy(&v, b + o, 4); return v; }

static void hdr(uint8_t *m, uint32_t size, int id, int complex)
{
	memset(m, 0, 0x18);
	w32(m, 0, (complex ? 0x80000000u : 0) | 0x1513); w32(m, 4, size); w32(m, 8, 1); w32(m, 12, 1); w32(m, 20, (uint32_t)id);
}

static int call(int fd, uint8_t *req, size_t n, uint8_t *rep, size_t cap)
{
	struct iovec v = { req, n }; int fds[4], nf = 0;
	if (ws_ipc_send(fd, &v, 1, NULL, 0)) return -1;
	return (int)ws_ipc_recv(fd, rep, cap, fds, &nf);
}

static int rc(int fd, uint8_t *req, size_t n) { uint8_t rep[0x100]; int got = call(fd, req, n, rep, sizeof rep); return got >= 0x24 ? (int)r32(rep, 0x20) : -9999; }

int main(void)
{
	ws_conn *c = ws_connect(NULL);
	if (!c) return 1;
	int fd = ws_conn_fd(c);
	{ int sw = 0, sh = 0; CHECK(ws_conn_screen(c, &sw, &sh) == 0 && sw == 640 && sh == 480); }
	{ /* WindowQuery with an empty query: complex reply, one descriptor slot, inline stream of three 0xffffffff list slots */
		uint8_t m[0x40], rep[0x100]; memset(m, 0, sizeof m); hdr(m, 0x2c, 30474, 0);
		int got = call(fd, m, 0x2c, rep, sizeof rep);
		CHECK(got == 0x48 && (r32(rep, 0) & 0x80000000u) && r32(rep, 0x14) == 30574 && r32(rep, 0x18) == 1 && r32(rep, 0x24) == 0x01000101u && r32(rep, 0x34) == 12 && r32(rep, 0x38) == 0xffffffffu && r32(rep, 0x40) == 0xffffffffu);
		hdr(m, 0x30, 30474, 0); w32(m, 0x28, 99);                                       /* length field does not match the size */
		got = call(fd, m, 0x30, rep, sizeof rep);
		CHECK(got == 0x24 && r32(rep, 0x20) == (uint32_t)-304);
	}
	{ /* window routines: GetScreenRectForWindow, InvalidateWindowShadow, SynchronizeWindowBackingStore, RemoveAllSurfaces, PostEventRecordTo */
		ws_win tw; CHECK(ws_win_create(c, (ws_rect){ 11, 22, 33, 44 }, 0, &tw) == 0 && ws_win_order(c, &tw, 1, 0) == 0);
		uint8_t m[0x400], rep[0x100]; int got;
		memset(m, 0, sizeof m); hdr(m, 0x24, 30028, 0); w32(m, 0x20, tw.id);
		got = call(fd, m, 0x24, rep, sizeof rep);
		{ float v[4]; memcpy(v, rep + 0x24, 16); CHECK(got == 0x34 && r32(rep, 0x20) == 0 && v[0] == 11 && v[1] == 22 && v[2] == 33 && v[3] == 44); }
		memset(m, 0, sizeof m); hdr(m, 0x24, 30028, 0); w32(m, 0x20, 0x7ffff);
		CHECK(rc(fd, m, 0x24) == 1000);
		memset(m, 0, sizeof m); hdr(m, 0x24, 30023, 0); w32(m, 0x20, tw.id); CHECK(rc(fd, m, 0x24) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x24, 30086, 0); w32(m, 0x20, tw.id); CHECK(rc(fd, m, 0x24) == 0);
		uint32_t sid = 0; CHECK(ws_surface_add(c, &tw, &sid) == 0 && sid);
		memset(m, 0, sizeof m); hdr(m, 0x24, 30092, 0); w32(m, 0x20, tw.id); CHECK(rc(fd, m, 0x24) == 0);
		int kind = -1; uint32_t ba = 0, bb = 0; CHECK(ws_surface_binding(c, &tw, sid, &kind, &ba, &bb) != 0);               /* the surface is gone */
		memset(m, 0, sizeof m); hdr(m, 0x24, 30092, 0); w32(m, 0x20, 0x7ffff); CHECK(rc(fd, m, 0x24) == 1000);
		uint8_t rec[512]; size_t rn = ws_evrec_make_key(rec, sizeof rec, 1, 13, 0, 0, 0, 0, 0, 0x0a); ws_event e; while (ws_conn_next_pushed_event(c, 0, &e)) {}
		memset(m, 0, sizeof m); hdr(m, (uint32_t)(0x2c + ((rn + 3) & ~3u)), 30120, 0); w32(m, 0x20, (uint32_t)getpid()); w32(m, 0x24, 1); w32(m, 0x28, (uint32_t)rn); memcpy(m + 0x2c, rec, rn);
		uint8_t *big = m; CHECK(rc(fd, big, 0x2c + ((rn + 3) & ~3u)) == 0);
		CHECK(ws_conn_next_pushed_event(c, 500, &e) == 1 && e.type == WS_EV_KEY_DOWN && e.key == 13 && e.wid == tw.id);
		w32(big, 0x20, 999999); CHECK(rc(fd, big, 0x2c + ((rn + 3) & ~3u)) == (int)(uint32_t)-600);
		ws_win_order(c, &tw, 0, 0);
	}
	{ /* SetEventCapture, SetWindowIsBuffered, WindowSetShadowProperties (OOL), SetTrackingAreaShape (OOL) */
		ws_win tw; CHECK(ws_win_create(c, (ws_rect){ 11, 22, 33, 44 }, 0, &tw) == 0);
		uint8_t m[0x80], rep[0x100]; memset(m, 0, sizeof m);
		hdr(m, 0x2c, 30055, 0); CHECK(rc(fd, m, 0x2c) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x28, 30019, 0); w32(m, 0x20, tw.id); CHECK(rc(fd, m, 0x28) == 0);
		w32(m, 0x20, 0x7ffff); CHECK(rc(fd, m, 0x28) == 1000);
		/* shadow properties: one OOL byte payload appended to the datagram */
		uint8_t o[0x80]; memset(o, 0, sizeof o); hdr(o, 0x3c, 30024, 1); w32(o, 0x18, 1); o[0x27] = 1; w32(o, 0x28, 4); w32(o, 0x34, tw.id); w32(o, 0x38, 4);
		int got = call(fd, o, 0x3c + 4, rep, sizeof rep); CHECK(got >= 0x24 && r32(rep, 0x20) == 0);
		w32(o, 0x34, 0x7ffff); got = call(fd, o, 0x3c + 4, rep, sizeof rep); CHECK(got >= 0x24 && r32(rep, 0x20) == 1000);
		w32(o, 0x34, tw.id); w32(o, 0x38, 5); got = call(fd, o, 0x3c + 4, rep, sizeof rep); CHECK(got >= 0x24 && r32(rep, 0x20) == (uint32_t)-300);
		/* tracking area shape: an empty region payload (size 0) is accepted for an owned window */
		memset(o, 0, sizeof o); hdr(o, 0x48, 30156, 1); w32(o, 0x18, 1); o[0x27] = 1; w32(o, 0x28, 0); w32(o, 0x34, tw.id); w32(o, 0x40, 0);
		got = call(fd, o, 0x48, rep, sizeof rep); CHECK(got >= 0x24 && r32(rep, 0x20) == 0);
		w32(o, 0x34, 0x7ffff); got = call(fd, o, 0x48, rep, sizeof rep); CHECK(got >= 0x24 && r32(rep, 0x20) == 1000);
	}
	{ /* FlushRegion, SetWindowClipShape (OOL empty regions) and ShapeSurface */
		ws_win tw; CHECK(ws_win_create(c, (ws_rect){ 1, 2, 30, 40 }, 0, &tw) == 0);
		uint8_t o[0x80], rep[0x100]; int got;
		memset(o, 0, sizeof o); hdr(o, 0x3c, 30081, 1); w32(o, 0x18, 1); o[0x27] = 1; w32(o, 0x34, tw.id);
		got = call(fd, o, 0x3c, rep, sizeof rep); CHECK(got >= 0x24 && r32(rep, 0x20) == 0);
		memset(o, 0, sizeof o); hdr(o, 0x3c, 30029, 1); w32(o, 0x18, 1); o[0x27] = 1; w32(o, 0x34, tw.id);
		got = call(fd, o, 0x3c, rep, sizeof rep); CHECK(got >= 0x24 && r32(rep, 0x20) == 0);
		memset(o, 0, sizeof o); hdr(o, 0x50, 30099, 1); w32(o, 0x18, 1); o[0x27] = 1;
		got = call(fd, o, 0x50, rep, sizeof rep); CHECK(got >= 0x24 && r32(rep, 0x20) == 0);
		w32(o, 0x4c, 3); got = call(fd, o, 0x50, rep, sizeof rep); CHECK(got >= 0x24 && r32(rep, 0x20) == (uint32_t)-300);
	}
	{ /* PostFilteredEventTapData, style 2 (SLEventPostToPid): the event reaches the process's frontmost window only */
		ws_win pw; CHECK(ws_win_create(c, (ws_rect){ 300, 300, 100, 60 }, 0, &pw) == 0 && ws_win_order(c, &pw, 1, 0) == 0);
		uint8_t rec[512]; size_t rn = ws_evrec_make_key(rec, sizeof rec, 1, 12, 0, 0, 0, 0, 0, 0x0a);
		ws_event e; while (ws_conn_next_pushed_event(c, 0, &e)) {}
		CHECK(rn > 0 && ws_post_event_to_pid(c, (int)getpid(), rec, rn) == 0);
		CHECK(ws_conn_next_pushed_event(c, 500, &e) == 1 && e.type == WS_EV_KEY_DOWN && e.key == 12 && e.wid == pw.id);
		rn = ws_evrec_make_mouse(rec, sizeof rec, 1, 320, 310, 0, 1, 0, 0);
		CHECK(ws_post_event_to_pid(c, (int)getpid(), rec, rn) == 0);
		CHECK(ws_conn_next_pushed_event(c, 500, &e) == 1 && e.type == WS_EV_MOUSE_DOWN && e.wid == pw.id && e.x == 20 && e.y == 10);       /* window-local */
		CHECK(ws_post_event_to_pid(c, 999999, rec, rn) == 0 && ws_conn_next_pushed_event(c, 200, &e) == 0);                                /* unknown pid: accepted, nothing delivered */
		ws_win_order(c, &pw, 0, 0);
	}
	{ /* capture: the composed pixels come back through a shared descriptor, for a window's frame, a rect or the whole screen */
		ws_win cw; CHECK(ws_win_create(c, (ws_rect){ 10, 20, 40, 30 }, 0, &cw) == 0);
		ws_surface *s = ws_capture(c, (ws_rect){ 0, 0, 0, 0 }, cw.id, 0);
		CHECK(s && s->w == 40 && s->h == 30); if (s) ws_surface_free(s);
		s = ws_capture(c, (ws_rect){ 0, 0, 8, 8 }, 0, 1);
		CHECK(s && s->w == 8 && s->h == 8); if (s) ws_surface_free(s);
		int sw = 0, sh = 0; CHECK(ws_conn_screen(c, &sw, &sh) == 0);
		s = ws_capture(c, (ws_rect){ 0, 0, 0, 0 }, 0, 0);
		CHECK(s && s->w == sw && s->h == sh); if (s) ws_surface_free(s);
		CHECK(ws_capture(c, (ws_rect){ 0, 0, 0, 0 }, 0xfffff, 0) == NULL);
	}
	{ /* GetWindowTransform: the identity for a window nothing transformed (recorded), 1000 for an unknown window, -304 for a bad size */
		ws_win tw; CHECK(ws_win_create(c, (ws_rect){ 100, 200, 30, 20 }, 0, &tw) == 0);
		uint8_t m[0x28], rep[0x80]; memset(m, 0, sizeof m); hdr(m, 0x28, 30034, 0); w32(m, 0x20, tw.id); w32(m, 0x24, 0x7fffff00);
		int g = call(fd, m, sizeof m, rep, sizeof rep); float f[6]; memcpy(f, rep + 0x28, 24);
		CHECK(g == 0x40 && r32(rep, 0x20) == 0 && f[0] == 1 && f[1] == 0 && f[2] == 0 && f[3] == 1 && f[4] == 0 && f[5] == 0);
		w32(m, 0x20, 0x7ffff); CHECK(rc(fd, m, sizeof m) == 1000);
		hdr(m, 0x24, 30034, 0); CHECK(rc(fd, m, 0x24) == -304);
	}
	{ /* shared memory regions: 32006 gives two port descriptors (0x34 bytes), 34006 three (0x40), each of 0x110000 bytes */
		uint8_t m[0x18], rep[0x80]; memset(m, 0, sizeof m); hdr(m, 0x18, 32006, 0);
		int g = call(fd, m, sizeof m, rep, sizeof rep);
		CHECK(g == 0x34 && r32(rep, 0x18) == 2 && r32(rep, 0x24) == 0x110000u && r32(rep, 0x30) == 0x110000u);
		hdr(m, 0x18, 34006, 0); g = call(fd, m, sizeof m, rep, sizeof rep);
		CHECK(g == 0x40 && r32(rep, 0x18) == 3 && r32(rep, 0x3c) == 0x110000u);
	}
	{ /* WindowQuery of one known window: the record laid out as the real server's reply (recorded on a macOS runner, lab/wq1.scen) for a window at 100,200,300,150, level 5, with a shadow */
		ws_win qw; CHECK(ws_win_create(c, (ws_rect){ 100, 200, 300, 150 }, 5, &qw) == 0 && ws_win_shadow(c, &qw, 10, 1) == 0);
		uint8_t m[0x60], rep[0x200]; memset(m, 0, sizeof m);
		uint8_t st[8]; size_t sn = 0; st[sn++] = 0x10; st[sn++] = 1;                         /* packed64: count 1 */
		if (qw.id < 0x100) { st[sn++] = 0x10; st[sn++] = (uint8_t)qw.id; } else { st[sn++] = 0x20; st[sn++] = (uint8_t)(qw.id >> 8); st[sn++] = (uint8_t)qw.id; }
		size_t msz = 0x2c + ((sn + 3) & ~3u); hdr(m, (uint32_t)msz, 30474, 0); w32(m, 0x28, (uint32_t)sn); memcpy(m + 0x2c, st, sn);
		int got = call(fd, m, msz, rep, sizeof rep);
		uint32_t slen = got > 0x38 ? r32(rep, 0x34) : 0;
		CHECK(got == (int)(((slen + 3) & ~3u) + 0x3c) && slen > 60 && r32(rep, 0x38) == slen - 8 && r32(rep, 0x3c) == 0xffffffffu && r32(rep, 0x40) == 0xffffffffu);
		const uint8_t *S = rep + 0x38;
		CHECK(r32(rep, 0x38 + slen - 8) == 1 && r32(rep, 0x38 + slen - 4) == 16);          /* index list: one entry, the record at offset 16 */
		CHECK(r32(rep, 0x38 + 12) == 0 && S[16] == 1);                                       /* zero word, then the new-window marker */
		size_t i = 17; int64_t v; int okp = 1;
		int64_t want[6] = { qw.id, ws_conn_id(c), 0, (int64_t)getpid(), 0, 0 };
		for (int k = 0; k < 6; k++) { size_t x = i; uint8_t t = S[x++]; int64_t val = 0; if (t < 0x10) val = -(t & 1); else { int nb = t >> 4; for (int q = 0; q < nb; q++) val = (val << 8) | S[x++]; } v = val; i = x; if (v != want[k]) okp = 0; }
		CHECK(okp);
		static const uint8_t suffix[] = { 0x10,5, 0x10,1, 0x10,0x64,0x10,0xc8,0x20,1,0x2c,0x10,0x96, 0x10,0x64,0x10,0xc8,0x20,1,0x2c,0x10,0x96,
			0x10,0x4d,0x10,0xb9,0x20,1,0x5a,0x10,0xc4, 0x10,0x4d,0x10,0xb9,0x20,1,0x5a,0x10,0xc4, 0,0, 0x10,0x0f,0, 0,0, 0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff,0xff, 0,0,0 };
		CHECK(i + sizeof suffix == slen - 8 && memcmp(S + i, suffix, sizeof suffix) == 0);
		{ /* flags 8 adds the display (recorded: 308 byte reply for one window, display list at 0xee) and flags 4 gives the window an empty space list at 0xc */
			uint8_t m2[0x60], r2[0x400]; memcpy(m2, m, sizeof m2); w32(m2, 0x20, 8);
			int g2 = call(fd, m2, msz, r2, sizeof r2); uint32_t l2 = g2 > 0x38 ? r32(r2, 0x34) : 0;
			CHECK(g2 > 0x38 && l2 == slen + 148 && r32(r2, 0x3c + 8) != 0xffffffffu);
			w32(m2, 0x20, 4); g2 = call(fd, m2, msz, r2, sizeof r2);
			static const uint8_t slot[] = { 0xff,0xff,0xff,0xff, 0x0c,0,0,0, 0xff,0xff,0xff,0xff };
			CHECK(g2 == got && memmem(r2 + 0x38, slen, slot, sizeof slot) != NULL);
		}
		/* count 0: every ordered-in window, front to back; option 1: only WindowServer-owned windows (none) */
		ws_win qw2; CHECK(ws_win_create(c, (ws_rect){ 5, 5, 20, 20 }, 0, &qw2) == 0 && ws_win_order(c, &qw, 1, 0) == 0 && ws_win_order(c, &qw2, 1, 0) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x30, 30474, 0); w32(m, 0x28, 1); m[0x2c] = 0;
		got = call(fd, m, 0x30, rep, sizeof rep);
		slen = got > 0x38 ? r32(rep, 0x34) : 0;
		{ uint32_t lo = r32(rep, 0x38); CHECK(slen > 100 && lo + 12 == slen && r32(rep, 0x38 + lo) == 2); CHECK(S[0] == S[0]); }
		memset(m, 0, sizeof m); hdr(m, 0x30, 30474, 0); w32(m, 0x28, 3); m[0x2c] = 0x00; m[0x2d] = 0x10; m[0x2e] = 1;
		got = call(fd, m, 0x30, rep, sizeof rep);
		CHECK(got == 0x48 && r32(rep, 0x34) == 12);
		ws_win_order(c, &qw, 0, 0); ws_win_order(c, &qw2, 0, 0);                         /* out again: later tests click around here */
		/* an unknown window id: the empty result */
		memset(m, 0, sizeof m); hdr(m, 0x30, 30474, 0); w32(m, 0x28, 4); m[0x2c] = 0x10; m[0x2d] = 1; m[0x2e] = 0x30; m[0x2f] = 0xff;
		got = call(fd, m, 0x30, rep, sizeof rep);
		CHECK(got == 0x48 && r32(rep, 0x34) == 12);
	}
	{ /* GetSymbolicHotKeyValuesAndStates: 3 ids -> reply 0x34 + 16 * 3, counts in front of every array */
		uint8_t m[0x40], rep[0x100]; memset(m, 0, sizeof m); hdr(m, 0x24 + 12, 32015, 0); w32(m, 0x20, 3); w32(m, 0x24, 1); w32(m, 0x28, 2); w32(m, 0x2c, 3);
		int got = call(fd, m, 0x24 + 12, rep, sizeof rep);
		CHECK(got == 0x34 + 48 && r32(rep, 0x14) == 32115 && r32(rep, 0x20) == 0 && r32(rep, 0x24) == 3 && r32(rep, 0x28 + 12) == 3 && r32(rep, 0x28 + 12 + 4 + 12) == 3 && r32(rep, 0x28 + 2 * (12 + 4) + 12) == 3);
		memset(m, 0, sizeof m); hdr(m, 0x24 + 4, 32015, 0); w32(m, 0x20, 3);
		got = call(fd, m, 0x24 + 4, rep, sizeof rep);
		CHECK(got == 0x24 && r32(rep, 0x20) == (uint32_t)-304);
	}
	{ /* routines with their 27.0 request shapes: appearance, RTL, debug options, dock rect, window manager, virtual display */
		uint8_t m[0x40], rep[0x100]; int got;
		static const struct { int id; uint32_t size; int rsize; int code; int val; } q[] = {
			{ 30176, 0x18, 0x28, 0, 0 }, { 30441, 0x18, 0x28, 0, 0 }, { 32003, 0x18, 0x28, 0, 0 },
			{ 30247, 0x18, 0x3c, 0, 0 }, { 30573, 0x18, 0x24, 0, 0 }, { 30577, 0x24, 0x24, 1001, 0 } };
		for (unsigned k = 0; k < sizeof q / sizeof *q; k++) {
			memset(m, 0, sizeof m); hdr(m, q[k].size, q[k].id, 0);
			got = call(fd, m, q[k].size, rep, sizeof rep);
			CHECK(got == q[k].rsize && r32(rep, 0x14) == (uint32_t)q[k].id + 100 && (int)r32(rep, 0x20) == q[k].code);
			if (q[k].rsize == 0x28) CHECK(r32(rep, 0x24) == (uint32_t)q[k].val);
		}
	}
	ws_win w;
	if (ws_win_create(c, (ws_rect){ 10, 10, 100, 80 }, 0, &w)) return 1;
	uint8_t m[0x200], rep[0x400];
	const char *key = "kCGSWindowTitle"; uint32_t kl = 16, P = 16;
	const uint8_t data[8] = { 'b', 'p', 'l', 'i', 's', 't', '0', '0' };

	/* WindowIsOrderedIn: 0 before ordering in, 1 after */
	hdr(m, 0x24, SLS_MSG_WindowIsOrderedIn, 0); memcpy(m + 0x18, &WS_NDR, 8); w32(m, 0x20, w.id);
	CHECK(call(fd, m, 0x24, rep, sizeof rep) == 0x28 && r32(rep, 0x24) == 0);
	ws_win_order(c, &w, 1, 0);
	CHECK(call(fd, m, 0x24, rep, sizeof rep) == 0x28 && r32(rep, 0x24) == 1);
	w32(m, 0x20, 99999);
	CHECK(call(fd, m, 0x24, rep, sizeof rep) == 0x28 && r32(rep, 0x24) == 0);

	/* SetWindowProperty (OOL data), then Get returns it; Delete removes it */
	size_t size = P + 0x44;
	memset(m, 0, sizeof m); hdr(m, (uint32_t)size, SLS_MSG_SetWindowProperty, 1);
	w32(m, 0x18, 1); m[0x25] = 1; m[0x27] = 1; w32(m, 0x28, sizeof data); memcpy(m + 0x2c, &WS_NDR, 8);
	w32(m, 0x34, w.id); w32(m, 0x3c, kl); memcpy(m + 0x40, key, 15); w32(m, 0x40 + P, sizeof data); memcpy(m + size, data, sizeof data);
	CHECK(rc(fd, m, size + sizeof data) == 0);
	w32(m, 0x40 + P, 7);                                                              /* repeated size differs: type error */
	CHECK(rc(fd, m, size + sizeof data) == -300);
	w32(m, 0x40 + P, sizeof data); w32(m, 0x34, 99999);                              /* unknown window */
	CHECK(rc(fd, m, size + sizeof data) == 1000);

	uint8_t g[0x2c + 16]; memset(g, 0, sizeof g); hdr(g, 0x2c + 16, SLS_MSG_GetWindowProperty, 0); memcpy(g + 0x18, &WS_NDR, 8);
	w32(g, 0x20, w.id); w32(g, 0x28, kl); memcpy(g + 0x2c, key, 15);
	int n = call(fd, g, 0x2c + 16, rep, sizeof rep);
	CHECK(n == 0x38 + 8 && (r32(rep, 0) & 0x80000000u) && r32(rep, 4) == 0x38 && r32(rep, 0x28) == 8 && r32(rep, 0x34) == 8 && memcmp(rep + 0x38, data, 8) == 0);
	hdr(g, 0x2c + 16, SLS_MSG_DeleteWindowProperty, 0); memcpy(g + 0x18, &WS_NDR, 8); w32(g, 0x20, w.id); w32(g, 0x28, kl); memcpy(g + 0x2c, key, 15);
	CHECK(rc(fd, g, 0x2c + 16) == 0);
	hdr(g, 0x2c + 16, SLS_MSG_GetWindowProperty, 0);
	n = call(fd, g, 0x2c + 16, rep, sizeof rep);
	CHECK(n == 0x38 && r32(rep, 0x34) == 0);                                          /* gone: an empty descriptor */
	hdr(g, 0x2c + 12, SLS_MSG_GetWindowProperty, 0);
	CHECK(rc(fd, g, 0x2c + 12) == -304);                                              /* wrong size */

	/* SetWindowLayerContext: the owner may bind a context; a stranger's window gives 1002 */
	hdr(m, 0x28, SLS_MSG_SetWindowLayerContext, 0); memcpy(m + 0x18, &WS_NDR, 8); w32(m, 0x20, w.id); w32(m, 0x24, 12345);
	CHECK(rc(fd, m, 0x28) == 0);
	w32(m, 0x20, 99999);
	CHECK(rc(fd, m, 0x28) == 1002);

	/* connection properties: Set (OOL), Get returns it, an unknown name gives an empty descriptor */
	{
		uint8_t cm[0x80 + 8]; size_t csz = P + 0x44; memset(cm, 0, sizeof cm);
		hdr(cm, (uint32_t)csz, SLS_MSG_SetConnectionProperty, 1);
		w32(cm, 0x18, 1); cm[0x25] = 1; cm[0x27] = 1; w32(cm, 0x28, 8); memcpy(cm + 0x2c, &WS_NDR, 8);
		w32(cm, 0x34, (uint32_t)ws_conn_id(c)); w32(cm, 0x3c, kl); memcpy(cm + 0x40, key, 15); w32(cm, 0x40 + P, 8); memcpy(cm + csz, data, 8);
		CHECK(rc(fd, cm, csz + 8) == 0);
		uint8_t q[0x2c + 16]; memset(q, 0, sizeof q); hdr(q, 0x2c + 16, SLS_MSG_GetConnectionProperty, 0); memcpy(q + 0x18, &WS_NDR, 8);
		w32(q, 0x20, (uint32_t)ws_conn_id(c)); w32(q, 0x28, kl); memcpy(q + 0x2c, key, 15);
		int gn = call(fd, q, sizeof q, rep, sizeof rep);
		CHECK(gn == 0x38 + 8 && r32(rep, 0x34) == 8 && memcmp(rep + 0x38, data, 8) == 0);
		memcpy(q + 0x2c, "kCGSOtherKey000", 15);
		gn = call(fd, q, sizeof q, rep, sizeof rep);
		CHECK(gn == 0x38 && r32(rep, 0x34) == 0);
	}
	/* notification interests and the opaque shape: sizes checked as on the real server, then accepted */
	{
		uint8_t nm[0x24 + 8]; memset(nm, 0, sizeof nm); hdr(nm, 0x24 + 8, SLS_MSG_SetConnectionNotifyInterests, 0); memcpy(nm + 0x18, &WS_NDR, 8); w32(nm, 0x20, 2); w32(nm, 0x24, 0x4b5); w32(nm, 0x28, 0x5e0);
		CHECK(rc(fd, nm, 0x24 + 8) == 0);
		w32(nm, 0x20, 3);
		CHECK(rc(fd, nm, 0x24 + 8) == -304);                                              /* count and size disagree */
		uint8_t os[0x3c + 8]; memset(os, 0, sizeof os); hdr(os, 0x3c, SLS_MSG_SetWindowOpaqueShape, 1);
		w32(os, 0x18, 1); os[0x25] = 1; os[0x27] = 1; w32(os, 0x28, 8); memcpy(os + 0x2c, &WS_NDR, 8); w32(os, 0x34, w.id); w32(os, 0x38, 8);
		CHECK(rc(fd, os, 0x3c + 8) == 0);
		w32(os, 0x38, 4);
		CHECK(rc(fd, os, 0x3c + 8) == -300);
		uint8_t cs[0x3c + 16]; memset(cs, 0, sizeof cs); hdr(cs, 0x3c, SLS_MSG_CopySpacesForWindows, 1);
		w32(cs, 0x18, 1); cs[0x25] = 1; cs[0x27] = 1; w32(cs, 0x28, 8); memcpy(cs + 0x2c, &WS_NDR, 8); w32(cs, 0x34, 0); w32(cs, 0x38, 2); w32(cs, 0x3c, w.id); w32(cs, 0x40, w.id);
		int sn = call(fd, cs, 0x3c + 8, rep, sizeof rep);
		CHECK(sn == 0x38 + 16 && r32(rep, 0x34) == 2 && r32(rep, 0x28) == 16);          /* two windows, one space each (u64 ids) */
	}

	/* ShapeWindow resizes (two OOL regions); GetWindowShape reads the shape back */
	{
		uint8_t reg[64]; size_t rn = ws_region_serialize(&(ws_rect){ 10, 10, 150, 90 }, 1, reg, sizeof reg);        /* screen coordinates: the bounds are the new frame */
		uint8_t sw[0x58 + 80]; memset(sw, 0, sizeof sw); hdr(sw, 0x58, SLS_MSG_ShapeWindow, 1);
		w32(sw, 0x18, 2); sw[0x25] = 1; sw[0x27] = 1; w32(sw, 0x28, (uint32_t)rn); sw[0x35] = 1; sw[0x37] = 1; w32(sw, 0x38, 0);
		memcpy(sw + 0x3c, &WS_NDR, 8); w32(sw, 0x44, w.id); w32(sw, 0x50, (uint32_t)rn); w32(sw, 0x54, 0); memcpy(sw + 0x58, reg, rn);
		CHECK(rc(fd, sw, 0x58 + rn) == 0);
		ws_rect fr; CHECK(ws_win_get_bounds(c, &w, &fr) == 0 && fr.w == 150 && fr.h == 90 && fr.x == 10 && fr.y == 10);
		hdr(g, 0x24, SLS_MSG_GetWindowShape, 0); memcpy(g + 0x18, &WS_NDR, 8); w32(g, 0x20, w.id);
		int sn = call(fd, g, 0x24, rep, sizeof rep);
		CHECK(sn > 0x38 && r32(rep, 0x28) == (uint32_t)(sn - 0x38));
		ws_rect *rr = NULL; int nrr = 0; ws_rect bbx;
		CHECK(ws_region_parse(rep + 0x38, (uint32_t)(sn - 0x38), &rr, &nrr, &bbx) == 0 && bbx.w == 150 && bbx.h == 90); free(rr);
		w32(g, 0x20, 99999);
		CHECK(rc(fd, g, 0x24) == 1000);
	}

	/* scroll and flags-changed records (bytes from CGEventCreateData on the real system) reach the window under the pointer / the key window */
	{
		static const char *scroll_hex = "000000020001403500000000000140360000000000014037000000160002c03842c80000434800000002c039bf800000bf8000000001003a00000000000003e80001403b0000010000014033000000000001403400000000000100a900000000000003e80001406a000000000001406b000000000001400b000000030001400cfffffffc0001400d00000000000140580000000000014089000000000001405d000300000001405efffc00000001405f00000000000140600000001e00014061ffffffd80001406200000000000140ad00000000000140630000000000014064000000000001c0af000000000001c0b0000000000001c0b1000000000001c0b200000000";
		static const char *flags_hex = "0000000200014035000000000001403600000000000140370000000c0002c03842c80000434800000002c039bf800000bf8000000001003a00000000000003e80001403b0002000000014033000000000001403400000000000100a900000000000003e80001406a000000000001406b00000000000140090000000000014008000000000001400a000000000001404c000000000001404d000000000001404e000000000001404f00000000000140500000000000014051000000000001407f00000000000140800000000000004052";
		ws_win w2;
		CHECK(ws_win_create(c, (ws_rect){ 50, 150, 100, 100 }, 0, &w2) == 0);
		ws_win_order(c, &w2, 1, 0); ws_win_set_event_mask(c, &w2, -1);
		ws_post_mouse_event(c, 5, 100, 200, 0, 0, 0); ws_post_mouse_event(c, 1, 100, 200, 0, 1, 0); ws_post_mouse_event(c, 2, 100, 200, 0, 1, 0);   /* click: w2 becomes the key window */
		uint8_t rec[1024];
		size_t rl = 0; for (const char *q = scroll_hex; q[0] && q[1]; q += 2) { unsigned v; sscanf(q, "%2x", &v); rec[rl++] = (uint8_t)v; }
		CHECK(ws_post_event_record(c, rec, rl) == 0);
		rl = 0; for (const char *q = flags_hex; q[0] && q[1]; q += 2) { unsigned v; sscanf(q, "%2x", &v); rec[rl++] = (uint8_t)v; }
		CHECK(ws_post_event_record(c, rec, rl) == 0);
		ws_event e; int got_scroll = 0, got_flags = 0;
		for (int i = 0; i < 20 && ws_conn_next_pushed_event(c, 200, &e); i++) {
			if (e.type == WS_EV_SCROLL) { got_scroll = 1; CHECK(e.wid == w2.id && e.dy == 30 && e.dx == -40 && e.continuous == 0 && e.x == 50 && e.y == 50); }
			if (e.type == WS_EV_FLAGS) { got_flags = 1; CHECK(e.flags == 0x20000); }
		}
		CHECK(got_scroll && got_flags);
	}

	/* transactions: the packed encodings (checked against bytes seen on the real system: wid 0x1d -> 10 1d, tags 5 -> 10 05, zero -> 00) and several operations in one stream */
	{
		uint8_t e[16];
		CHECK(ws_tx_packed(e, 0x1d) == 2 && e[0] == 0x10 && e[1] == 0x1d);
		CHECK(ws_tx_packed(e, 5) == 2 && e[0] == 0x10 && e[1] == 0x05);
		CHECK(ws_tx_packed(e, 0) == 1 && e[0] == 0x00);
		CHECK(ws_tx_packed(e, -1) == 1 && e[0] == 0x01);
		CHECK(ws_tx_packed(e, -5) == 2 && e[0] == 0x11 && e[1] == 0xfb);
		CHECK(ws_tx_packed(e, 0x1234) == 3 && e[0] == 0x20 && e[1] == 0x12 && e[2] == 0x34);
		uint8_t st[256]; size_t n = 0;
		st[n++] = 3; n += ws_tx_packed(st + n, w.id); n += ws_tx_float(st + n, 0.25f); n += ws_tx_float(st + n, 0.0f);            /* SetWindowAlpha */
		st[n++] = 6; n += ws_tx_packed(st + n, w.id); n += ws_tx_packed(st + n, 7);                                                 /* SetWindowLevel */
		st[n++] = 12; n += ws_tx_packed(st + n, w.id); n += ws_tx_packed(st + n, 4);                                                /* SetWindowSubLevel */
		st[n++] = 22; n += ws_tx_packed(st + n, w.id); n += ws_tx_double(st + n, 33.0); n += ws_tx_double(st + n, 44.0);              /* MoveWindowWithGroup */
		st[n++] = 118; n += ws_tx_packed(st + n, w.id); n += ws_tx_packed(st + n, 0x30); n += ws_tx_packed(st + n, 0); st[n++] = 0;  /* SetWindowTags */
		st[n++] = 0xff;
		CHECK(ws_transaction_commit(c, st, n, 1) == 0);
		float al = -1; int lv = -1, sub = -1; ws_rect fr2;
		CHECK(ws_win_get_alpha(c, &w, &al) == 0 && al == 0.25f);
		CHECK(ws_win_get_level(c, &w, &lv) == 0 && lv == 7);
		CHECK(ws_win_get_sublevel(c, &w, &sub) == 0 && sub == 4);
		CHECK(ws_win_get_bounds(c, &w, &fr2) == 0 && fr2.x == 33 && fr2.y == 44);
		uint8_t tg[0x24]; memset(tg, 0, sizeof tg); hdr(tg, 0x24, SLS_MSG_GetWindowTags, 0); memcpy(tg + 0x18, &WS_NDR, 8); w32(tg, 0x20, w.id);
		CHECK(call(fd, tg, 0x24, rep, sizeof rep) == 0x2c && r32(rep, 0x24) == 0x30);
		/* a stream with an unknown opcode or truncated arguments is refused; an operation on someone else's window is silently ignored */
		uint8_t bad[4] = { 0x8d, 0xff };
		CHECK(ws_transaction_commit(c, bad, 2, 0) == 1001);
		uint8_t trunc[3] = { 6, 0x10, 0x05 };
		CHECK(ws_transaction_commit(c, trunc, 3, 0) == 1001);
		uint8_t foreign[16]; size_t fn = 0; foreign[fn++] = 6; fn += ws_tx_packed(foreign + fn, 99999); fn += ws_tx_packed(foreign + fn, 3); foreign[fn++] = 0xff;
		CHECK(ws_transaction_commit(c, foreign, fn, 0) == 0);
		/* exactly one of inline and out-of-line: both -> 1001 */
		uint8_t both[0x48 + 8 + 8]; memset(both, 0, sizeof both); hdr(both, 0x48 + 4, SLS_MSG_TransactionCommitAsync, 1);
		w32(both, 0x18, 1); both[0x25] = 1; both[0x27] = 1; w32(both, 0x28, 4); memcpy(both + 0x2c, &WS_NDR, 8); w32(both, 0x40, 1); both[0x44] = 0xff; w32(both, 0x48, 4); memcpy(both + 0x4c, "\xff\0\0\0", 4);
		CHECK(rc(fd, both, 0x4c + 4) == 1001);
	}

	/* surface binding through a transaction: BindSurface (kind 4, buffer) then RemoveSurface */
	{
		ws_cbuf cb; uint32_t sid = 0;
		CHECK(ws_cbuf_create(c, 32, 32, &cb) == 0 && ws_surface_add(c, &w, &sid) == 0 && sid);
		uint8_t st[64]; size_t n = 0;
		st[n++] = 51; n += ws_tx_packed(st + n, w.id); n += ws_tx_packed(st + n, sid); n += ws_tx_packed(st + n, 4); n += ws_tx_packed(st + n, 0); n += ws_tx_packed(st + n, cb.id); st[n++] = 0xff;
		CHECK(ws_transaction_commit(c, st, n, 0) == 0);
		int kind = -1; uint32_t ba = 9, bb = 0;
		CHECK(ws_surface_binding(c, &w, sid, &kind, &ba, &bb) == 0 && kind == 4 && bb == cb.id);
		n = 0; st[n++] = 95; n += ws_tx_packed(st + n, w.id); n += ws_tx_packed(st + n, sid); st[n++] = 0xff;
		CHECK(ws_transaction_commit(c, st, n, 0) == 0);
		CHECK(ws_surface_binding(c, &w, sid, &kind, &ba, &bb) != 0);                      /* gone */
		n = 0; st[n++] = 105; n += ws_tx_packed(st + n, w.id); n += ws_tx_double(st + n, 12.0); st[n++] = 0xff;
		CHECK(ws_transaction_commit(c, st, n, 0) == 0);
	}

	/* the displays and devices property lists: an OOL binary plist each */
	{
		uint8_t q[0x18]; hdr(q, 0x18, SLS_MSG_CopyManagedDisplays, 0);
		int dn = call(fd, q, 0x18, rep, sizeof rep);
		CHECK(dn == 0x38 + 83 && r32(rep, 0x28) == 83 && memcmp(rep + 0x38, "bplist00", 8) == 0);
		hdr(q, 0x18, SLS_MSG_GetDevices, 0);
		dn = call(fd, q, 0x18, rep, sizeof rep);
		CHECK(dn > 0x38 + 8 && memcmp(rep + 0x38, "bplist00", 8) == 0 && r32(rep, 0x34) == (uint32_t)(dn - 0x38));
	}

	/* tracking regions: entering and leaving a region of the window under the pointer is reported with the region id */
	{
		uint8_t reg[64]; size_t rn = ws_region_serialize(&(ws_rect){ 0, 0, 50, 50 }, 1, reg, sizeof reg);
		uint8_t tm[0x58 + 64]; memset(tm, 0, sizeof tm); hdr(tm, 0x58, SLS_MSG_AddStructuralRegionOfType, 1);
		w32(tm, 0x18, 1); tm[0x25] = 1; tm[0x27] = 1; w32(tm, 0x28, (uint32_t)rn); memcpy(tm + 0x2c, &WS_NDR, 8);
		w32(tm, 0x34, 1); w32(tm, 0x38, w.id); w32(tm, 0x48, (uint32_t)rn); w32(tm, 0x50, 0x2339); memcpy(tm + 0x58, reg, rn);
		CHECK(rc(fd, tm, 0x58 + rn) == 0);
		ws_win_set_event_mask(c, &w, -1);
		ws_event e; while (ws_conn_next_pushed_event(c, 20, &e)) { }
		ws_post_mouse_event(c, 5, 40, 50, 0, 0, 0);                                      /* local (7, 6) inside the region */
		int entered = 0, exited = 0;
		for (int i = 0; i < 10 && ws_conn_next_pushed_event(c, 100, &e); i++) if (e.type == WS_EV_TRACK_ENTER && e.key == 0x2339 && e.wid == w.id) entered = 1;
		ws_post_mouse_event(c, 5, 120, 100, 0, 0, 0);                                    /* still in the window, outside the region */
		for (int i = 0; i < 10 && ws_conn_next_pushed_event(c, 100, &e); i++) if (e.type == WS_EV_TRACK_EXIT && e.key == 0x2339) exited = 1;
		CHECK(entered && exited);
		uint8_t rm[0x28]; memset(rm, 0, sizeof rm); hdr(rm, 0x28, SLS_MSG_RemoveStructuralRegion, 0); memcpy(rm + 0x18, &WS_NDR, 8); w32(rm, 0x20, 0x2339);
		CHECK(rc(fd, rm, 0x28) == 0);
		ws_post_mouse_event(c, 5, 40, 50, 0, 0, 0);
		int again = 0; for (int i = 0; i < 5 && ws_conn_next_pushed_event(c, 60, &e); i++) if (e.type == WS_EV_TRACK_ENTER) again = 1;
		CHECK(!again);                                                                    /* removed: no more events */
	}

	/* connection state: gesture submask, coalescing, SetNotifications (needs the process record), SetFrontProcess, GetHeldWindowRights */
	{
		uint8_t m[0x40], rep[0x100]; int got; ws_win hw; CHECK(ws_win_create(c, (ws_rect){ 720, 520, 20, 20 }, 0, &hw) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x28, 30251, 0); w32(m, 0x20, 7); CHECK(rc(fd, m, 0x28) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x24, 30208, 0); w32(m, 0x20, 0x98000e0); CHECK(rc(fd, m, 0x24) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x30, 30119, 0); w32(m, 0x20, 0x99); w32(m, 0x24, 0x99); w32(m, 0x28, 0x1e); CHECK(rc(fd, m, 0x30) == (int)(uint32_t)-50);   /* no process record on this connection */
		memset(m, 0, sizeof m); hdr(m, 0x30, 30118, 0); w32(m, 0x20, 1); w32(m, 0x24, 2); CHECK(rc(fd, m, 0x30) == (int)(uint32_t)-600);                          /* no such process */
		memset(m, 0, sizeof m); hdr(m, 0x24, 30276, 0); w32(m, 0x20, hw.id); got = call(fd, m, 0x24, rep, sizeof rep); CHECK(got == 0x30 && r32(rep, 0x20) == 0 && r32(rep, 0x24) == 1 && r32(rep, 0x28) == 0x30006 && r32(rep, 0x2c) == 0x10000);
		w32(m, 0x20, 0x7ffff); CHECK(rc(fd, m, 0x24) == 0x3e9);
	}

	/* spaces: create, name, look up by name, alpha, put a window in a space (CopySpacesForWindows follows), remove, destroy */
	{
		ws_win sw; CHECK(ws_win_create(c, (ws_rect){ 700, 500, 30, 30 }, 0, &sw) == 0);
		uint8_t m[0x100], rep[0x100]; int got;
		memset(m, 0, sizeof m); hdr(m, 0x3c, 30328, 1); w32(m, 0x18, 1); m[0x25] = 1; m[0x27] = 1; w32(m, 0x28, 0); memcpy(m + 0x2c, &WS_NDR, 8); w32(m, 0x34, 0); w32(m, 0x38, 0);
		got = call(fd, m, 0x3c, rep, sizeof rep); uint64_t sid = 0; if (got == 0x2c) memcpy(&sid, rep + 0x24, 8);
		CHECK(got == 0x2c && r32(rep, 0x20) == 0 && sid >= 2);
		memset(m, 0, sizeof m); hdr(m, 0x30 + 4, 30334, 0); memcpy(m + 0x20, &sid, 8); w32(m, 0x2c, 4); memcpy(m + 0x30, "work", 4); CHECK(rc(fd, m, 0x34) == 0);
		uint8_t bp[16]; memcpy(bp, "bplist00", 8); bp[8] = 0x54; memcpy(bp + 9, "work", 4);
		uint8_t wm[0x38 + 16]; memset(wm, 0, sizeof wm); hdr(wm, 0x38, 30349, 1); w32(wm, 0x18, 1); wm[0x25] = 1; wm[0x27] = 1; w32(wm, 0x28, 13); memcpy(wm + 0x2c, &WS_NDR, 8); w32(wm, 0x34, 13); memcpy(wm + 0x38, bp, 13);
		got = call(fd, wm, 0x38 + 13, rep, sizeof rep); uint64_t found = 0; if (got == 0x2c) memcpy(&found, rep + 0x24, 8);
		CHECK(got == 0x2c && found == sid);
		memcpy(wm + 0x38 + 9, "nope", 4); got = call(fd, wm, 0x38 + 13, rep, sizeof rep); found = 1; if (got == 0x2c) memcpy(&found, rep + 0x24, 8); CHECK(got == 0x2c && found == 0);
		memset(m, 0, sizeof m); hdr(m, 0x28, 30442, 0); memcpy(m + 0x20, &sid, 8); got = call(fd, m, 0x28, rep, sizeof rep); { float f; memcpy(&f, rep + 0x24, 4); CHECK(got == 0x28 && f == 1.0f); }
		uint64_t bad = 0xdead; memcpy(m + 0x20, &bad, 8); CHECK(rc(fd, m, 0x28) == 0x3f2);
		/* AddWindowsToSpaces: one window, one space */
		uint8_t am[0x4c + 12]; memset(am, 0, sizeof am); hdr(am, 0x4c, 30319, 1); w32(am, 0x18, 2); am[0x25] = 1; am[0x27] = 1; w32(am, 0x28, 4); am[0x35] = 1; am[0x37] = 1; w32(am, 0x38, 8); memcpy(am + 0x3c, &WS_NDR, 8); w32(am, 0x44, 1); w32(am, 0x48, 1);
		w32(am, 0x4c, sw.id); memcpy(am + 0x50, &sid, 8);
		CHECK(rc(fd, am, 0x4c + 12) == 0);
		uint8_t cm[0x3c + 4]; memset(cm, 0, sizeof cm); hdr(cm, 0x3c, SLS_MSG_CopySpacesForWindows, 1); w32(cm, 0x18, 1); cm[0x25] = 1; cm[0x27] = 1; w32(cm, 0x28, 4); memcpy(cm + 0x2c, &WS_NDR, 8); w32(cm, 0x38, 1); w32(cm, 0x3c, sw.id);
		uint8_t big[0x100]; got = call(fd, cm, 0x40, big, sizeof big); uint64_t in = 0; if (got >= 0x38 + 8) memcpy(&in, big + 0x38, 8); CHECK(in == sid);
		hdr(am, 0x4c, 30320, 1); CHECK(rc(fd, am, 0x4c + 12) == 0);
		got = call(fd, cm, 0x40, big, sizeof big); in = 0; if (got >= 0x38 + 8) memcpy(&in, big + 0x38, 8); CHECK(in == 1);                      /* back in the default space */
		memset(m, 0, sizeof m); hdr(m, 0x28, 30329, 0); memcpy(m + 0x20, &sid, 8); CHECK(rc(fd, m, 0x28) == 0); CHECK(rc(fd, m, 0x28) == 0x3e9);   /* destroyed; again: unknown */
		uint64_t one = 1; memcpy(m + 0x20, &one, 8); CHECK(rc(fd, m, 0x28) == 0x3e9);                                                                  /* the default space stays */
	}

	/* notifications: ToConnection reaches the target, Broadcast only the connections that registered the type; events and notifications share the channel */
	{
		uint32_t type = 0, n = 0; uint8_t d[256]; ws_event e; while (ws_conn_next_pushed_event(c, 0, &e)) {}
		CHECK(ws_notification_post(c, (uint32_t)ws_conn_id(c), 0x77, (const uint8_t *)"hello", 5) == 0);
		CHECK(ws_conn_next_notification(c, 500, &type, d, &n) == 1 && type == 0x77 && n == 5 && memcmp(d, "hello", 5) == 0);
		CHECK(ws_notification_post(c, 0x7fffff, 0x77, (const uint8_t *)"x", 1) == 0 && ws_conn_next_notification(c, 100, &type, d, &n) == 0);            /* unknown target: accepted, nothing delivered */
		uint8_t m[0x30]; memset(m, 0, sizeof m); hdr(m, 0x28, SLS_MSG_SetConnectionNotifyInterests, 0); w32(m, 0x20, 1); w32(m, 0x24, 0x88); CHECK(rc(fd, m, 0x28) == 0);
		CHECK(ws_notification_broadcast(c, 0x99, (const uint8_t *)"no", 2) == 0 && ws_conn_next_notification(c, 100, &type, d, &n) == 0);                       /* not registered */
		CHECK(ws_notification_broadcast(c, 0x88, (const uint8_t *)"yes", 3) == 0 && ws_conn_next_notification(c, 500, &type, d, &n) == 1 && type == 0x88 && n == 3 && memcmp(d, "yes", 3) == 0);
		ws_win nw; CHECK(ws_win_create(c, (ws_rect){ 300, 200, 100, 100 }, 0, &nw) == 0 && ws_win_order(c, &nw, 1, 0) == 0); ws_win_set_event_mask(c, &nw, -1);
		while (ws_conn_next_pushed_event(c, 20, &e)) {}
		ws_post_mouse_event(c, 5, 321, 222, 0, 0, 0);                                                                                                       /* events still arrive after notifications */
		CHECK(ws_notification_post(c, (uint32_t)ws_conn_id(c), 0x55, (const uint8_t *)"z", 1) == 0);
		int got_move = 0; for (int i = 0; i < 6 && ws_conn_next_pushed_event(c, 100, &e); i++) if (e.type == WS_EV_MOUSE_MOVE) got_move = 1;
		CHECK(got_move && ws_conn_next_notification(c, 100, &type, d, &n) == 1 && type == 0x55);
		ws_win_order(c, &nw, 0, 0);
		memset(m, 0, sizeof m); hdr(m, 0x24, SLS_MSG_SetConnectionNotifyInterests, 0); w32(m, 0x20, 0); CHECK(rc(fd, m, 0x24) == 0);
	}

	/* SetWindowEventShape: events go where the event shape is, not where the window is drawn; window regions are named values; BlockWindowOrdering */
	{
		ws_win ew; CHECK(ws_win_create(c, (ws_rect){ 600, 400, 40, 40 }, 0, &ew) == 0 && ws_win_order(c, &ew, 1, 0) == 0);
		CHECK(ws_win_find(c, 605, 405) == ew.id);                                              /* inside the frame */
		uint8_t reg[64]; size_t rn = ws_region_serialize(&(ws_rect){ 20, 20, 10, 10 }, 1, reg, sizeof reg);
		uint8_t em[0x3c + 64], rep[0x100]; memset(em, 0, sizeof em); hdr(em, 0x3c, 30225, 1); w32(em, 0x18, 1); em[0x25] = 1; em[0x27] = 1; w32(em, 0x28, (uint32_t)rn); memcpy(em + 0x2c, &WS_NDR, 8); w32(em, 0x34, ew.id); w32(em, 0x38, (uint32_t)rn); memcpy(em + 0x3c, reg, rn);
		int got = call(fd, em, 0x3c + rn, rep, sizeof rep); CHECK(got >= 0x24 && r32(rep, 0x20) == 0);
		CHECK(ws_win_find(c, 605, 405) != ew.id);                                              /* outside the event shape now */
		CHECK(ws_win_find(c, 625, 425) == ew.id);                                              /* inside it */
		w32(em, 0x28, 0); w32(em, 0x38, 0); got = call(fd, em, 0x3c, rep, sizeof rep); CHECK(got >= 0x24 && r32(rep, 0x20) == 0);          /* an empty region clears it */
		CHECK(ws_win_find(c, 605, 405) == ew.id);
		uint8_t m[0x40]; memset(m, 0, sizeof m); hdr(m, 0x24, 30167, 0); w32(m, 0x20, 5); got = call(fd, m, 0x24, rep, sizeof rep); CHECK(got == 0x28 && r32(rep, 0x24) == 1);
		ws_win_order(c, &ew, 0, 0);
	}

	/* cursor routines: the region lock keeps the pointer inside; another connection cannot take it; restriction mode/options, drag lock, obscure and wait cursor are accepted */
	{
		uint8_t reg[64]; size_t rn = ws_region_serialize(&(ws_rect){ 100, 100, 50, 50 }, 1, reg, sizeof reg), got;
		uint8_t lm[0x38 + 64]; memset(lm, 0, sizeof lm); hdr(lm, 0x38, 30459, 1); w32(lm, 0x18, 1); lm[0x25] = 1; lm[0x27] = 1; w32(lm, 0x28, (uint32_t)rn); memcpy(lm + 0x2c, &WS_NDR, 8); w32(lm, 0x34, (uint32_t)rn); memcpy(lm + 0x38, reg, rn);
		CHECK(rc(fd, lm, 0x38 + rn) == 0);
		int cx = -1, cy = -1;
		ws_post_mouse_event(c, 5, 5, 5, 0, 0, 0); ws_cursor_position(c, &cx, &cy); CHECK(cx == 100 && cy == 100);                              /* clamped to the region's corner */
		ws_post_mouse_event(c, 5, 500, 400, 0, 0, 0); ws_cursor_position(c, &cx, &cy); CHECK(cx == 149 && cy == 149);
		ws_post_mouse_event(c, 5, 120, 130, 0, 0, 0); ws_cursor_position(c, &cx, &cy); CHECK(cx == 120 && cy == 130);                          /* inside: untouched */
		uint8_t q[0x40]; memset(q, 0, sizeof q);
		w32(lm, 0x28, 0); w32(lm, 0x34, 0); CHECK(rc(fd, lm, 0x38) == 0);                                                                    /* an empty region releases */
		memset(q, 0, sizeof q); hdr(q, 0x24, 30545, 0); w32(q, 0x20, 2); CHECK(rc(fd, q, 0x24) == 0);
		memset(q, 0, sizeof q); hdr(q, 0x28, 30548, 0); w32(q, 0x20, 1); CHECK(rc(fd, q, 0x28) == 0);
		memset(q, 0, sizeof q); hdr(q, 0x40, 30458, 0); CHECK(rc(fd, q, 0x40) == 0);
		memset(q, 0, sizeof q); hdr(q, 0x28, 30476, 0); CHECK(rc(fd, q, 0x28) == 0);
		memset(q, 0, sizeof q); hdr(q, 0x24, 30127, 0); CHECK(rc(fd, q, 0x24) == 0);
		(void)got;
	}

	/* window lists: OrderWindowListWithOperation, SetWindowListSystemAlpha / Level, CopyWindowsWithOptionsAndTags */
	{
		ws_win a1, a2; CHECK(ws_win_create(c, (ws_rect){ 500, 400, 30, 30 }, 0, &a1) == 0 && ws_win_create(c, (ws_rect){ 510, 410, 30, 30 }, 0, &a2) == 0);
		CHECK(ws_win_order(c, &a1, 1, 0) == 0 && ws_win_order(c, &a2, 1, 0) == 0);
		uint8_t m[0x100], rep[0x400]; int got; uint32_t ids[16]; int total = 0;
		memset(m, 0, sizeof m); hdr(m, 0x2c + 4, 30233, 0); w32(m, 0x20, 1); w32(m, 0x24, a1.id); w32(m, 0x28, 1); w32(m, 0x2c, 0);          /* a1 above everything */
		CHECK(rc(fd, m, 0x30) == 0);
		int lr = ws_win_list(c, 0, 1, ids, 16, &total), p1 = -1, p2 = -1; for (int i = 0; i < 16 && i < total; i++) { if (ids[i] == a1.id) p1 = i; if (ids[i] == a2.id) p2 = i; }
		CHECK(lr >= 0 && p1 >= 0 && p2 >= 0 && p1 < p2);                                                                                      /* a1 is in front of a2 */                                                                 /* a1 is the frontmost */
		memset(m, 0, sizeof m); hdr(m, 0x2c, 30233, 0); w32(m, 0x20, 0); CHECK(rc(fd, m, 0x2c) == 1000);                                       /* empty list */
		memset(m, 0, sizeof m); hdr(m, 0x2c + 4, 30233, 0); w32(m, 0x20, 1); w32(m, 0x24, 0x7ffff); CHECK(rc(fd, m, 0x30) == 1000);             /* unknown window */
		/* system alpha: one id, one float 0.5 */
		memset(m, 0, sizeof m); hdr(m, 0x28 + 8, 30040, 0); w32(m, 0x20, 1); w32(m, 0x24, a2.id); w32(m, 0x28, 1); { float f = 0.5f; memcpy(m + 0x2c, &f, 4); }
		CHECK(rc(fd, m, 0x30) == 0);
		w32(m, 0x28, 2); CHECK(rc(fd, m, 0x30) == (int)(uint32_t)-304);                                                                        /* the counts do not match the size */
		/* system level: class 1, one window; class 5 refused; empty list refused */
		memset(m, 0, sizeof m); hdr(m, 0x2c + 4, 30257, 0); w32(m, 0x20, 1); w32(m, 0x24, 1); w32(m, 0x28, a2.id); CHECK(rc(fd, m, 0x30) == 0);
		w32(m, 0x20, 5); CHECK(rc(fd, m, 0x30) == 0x3e9);
		memset(m, 0, sizeof m); hdr(m, 0x2c, 30257, 0); w32(m, 0x20, 1); w32(m, 0x24, 0); CHECK(rc(fd, m, 0x2c) == 1000);
		/* the list of windows: ordered-in ones, front to back (no space filter) */
		memset(m, 0, sizeof m); hdr(m, 0x50, 30326, 1); w32(m, 0x18, 1); m[0x25] = 1; m[0x27] = 1; w32(m, 0x28, 0); memcpy(m + 0x2c, &WS_NDR, 8);
		got = call(fd, m, 0x50, rep, sizeof rep);
		CHECK(got >= 0x38 && (r32(rep, 0) & 0x80000000u) && r32(rep, 0x34) == (uint32_t)(got - 0x38) / 4 && r32(rep, 0x28) == r32(rep, 0x34) * 4 && got >= 0x38 + 8);
		{ int q1 = -1, q2 = -1; for (uint32_t i = 0; i < r32(rep, 0x34); i++) { if (r32(rep, 0x38 + 4 * i) == a1.id) q1 = (int)i; if (r32(rep, 0x38 + 4 * i) == a2.id) q2 = (int)i; } CHECK(q1 >= 0 && q2 >= 0 && q1 < q2); }
		ws_win_order(c, &a1, 0, 0); ws_win_order(c, &a2, 0, 0);
	}

	/* hot keys: per-connection records, the operating mode and the symbolic table */
	{
		uint8_t m[0x40], rep[0x100]; int got;
		uint64_t hid = 0x1122334455ULL;
		memset(m, 0, sizeof m); hdr(m, 0x28, 30199, 0); memcpy(m + 0x20, &hid, 8); CHECK(rc(fd, m, 0x28) == 0x3ef);                          /* unknown */
		memset(m, 0, sizeof m); hdr(m, 0x38, 30200, 0); memcpy(m + 0x20, &hid, 8); w32(m, 0x28, 0x2c); w32(m, 0x2c, 0x100); w32(m, 0x30, 7); CHECK(rc(fd, m, 0x38) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x28, 30199, 0); memcpy(m + 0x20, &hid, 8); got = call(fd, m, 0x28, rep, sizeof rep);
		CHECK(got == 0x30 && r32(rep, 0x20) == 0 && r32(rep, 0x24) == 0x2c && r32(rep, 0x28) == 0x100 && r32(rep, 0x2c) == 7);
		memset(m, 0, sizeof m); hdr(m, 0x28, 30201, 0); memcpy(m + 0x20, &hid, 8); got = call(fd, m, 0x28, rep, sizeof rep); CHECK(got == 0x28 && r32(rep, 0x24) == 1);
		memset(m, 0, sizeof m); hdr(m, 0x2c, 30202, 0); memcpy(m + 0x20, &hid, 8); w32(m, 0x28, 0); CHECK(rc(fd, m, 0x2c) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x28, 30201, 0); memcpy(m + 0x20, &hid, 8); got = call(fd, m, 0x28, rep, sizeof rep); CHECK(got == 0x28 && r32(rep, 0x24) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x2c, 30230, 0); memcpy(m + 0x20, &hid, 8); w32(m, 0x28, 0x13); CHECK(rc(fd, m, 0x2c) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x28, 30229, 0); memcpy(m + 0x20, &hid, 8); got = call(fd, m, 0x28, rep, sizeof rep); CHECK(got == 0x28 && r32(rep, 0x24) == 0x17);
		memset(m, 0, sizeof m); hdr(m, 0x28, 30203, 0); memcpy(m + 0x20, &hid, 8); CHECK(rc(fd, m, 0x28) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x28, 30199, 0); memcpy(m + 0x20, &hid, 8); CHECK(rc(fd, m, 0x28) == 0x3ef);
		memset(m, 0, sizeof m); hdr(m, 0x24, 30210, 0); w32(m, 0x20, 3); CHECK(rc(fd, m, 0x24) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x18, 30211, 0); got = call(fd, m, 0x18, rep, sizeof rep); CHECK(got == 0x28 && r32(rep, 0x24) == 3);
		/* symbolic */
		memset(m, 0, sizeof m); hdr(m, 0x24, 32011, 0); w32(m, 0x20, 0x108 + 1); CHECK(rc(fd, m, 0x24) == 0x3ef);                                              /* out of range */
		memset(m, 0, sizeof m); hdr(m, 0x24, 32011, 0); w32(m, 0x20, 0); got = call(fd, m, 0x24, rep, sizeof rep);
		CHECK(got == 0x30 && r32(rep, 0x24) == 0xffff && r32(rep, 0x28) == 53 && r32(rep, 0x2c) == 0x180000);                                          /* id 0: Cmd-Opt-Esc, as on the real server */
		memset(m, 0, sizeof m); hdr(m, 0x30, 32012, 0); w32(m, 0x20, 7); w32(m, 0x24, 0x78); w32(m, 0x28, 0x1000); w32(m, 0x2c, 5); CHECK(rc(fd, m, 0x30) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x24, 32011, 0); w32(m, 0x20, 7); got = call(fd, m, 0x24, rep, sizeof rep);
		CHECK(got == 0x30 && r32(rep, 0x24) == 0x78 && r32(rep, 0x28) == 0x1000 && r32(rep, 0x2c) == 5);
		memset(m, 0, sizeof m); hdr(m, 0x28, 32014, 0); w32(m, 0x20, 7); w32(m, 0x24, 1); CHECK(rc(fd, m, 0x28) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x24, 32013, 0); w32(m, 0x20, 7); got = call(fd, m, 0x24, rep, sizeof rep); CHECK(got == 0x28 && r32(rep, 0x24) == 1);
		memset(m, 0, sizeof m); hdr(m, 0x28, 32014, 0); w32(m, 0x20, 0x500); w32(m, 0x24, 1); CHECK(rc(fd, m, 0x28) == 0x3e9);
		memset(m, 0, sizeof m); hdr(m, 0x24 + 8, 32015, 0); w32(m, 0x20, 2); w32(m, 0x24, 7); w32(m, 0x28, 8);                                           /* the values and states of ids 7 and 8 */
		uint8_t big[0x100]; got = call(fd, m, 0x2c, big, sizeof big);
		CHECK(got == 0x34 + 32 && r32(big, 0x28) == 0x78 && r32(big, 0x28 + 8 + 4) == 0x1000);
	}

	/* SetWindowParent, GetParentWindowList, WindowIsVisible, and the parent in WindowQuery records */
	{
		ws_win pa, ch; CHECK(ws_win_create(c, (ws_rect){ 400, 300, 50, 50 }, 0, &pa) == 0 && ws_win_create(c, (ws_rect){ 410, 310, 20, 20 }, 0, &ch) == 0);
		uint8_t m[0x1040], rep[0x1100]; memset(m, 0, sizeof m); hdr(m, 0x28, 30249, 0); w32(m, 0x20, ch.id); w32(m, 0x24, pa.id); CHECK(rc(fd, m, 0x28) == 0);
		memset(m, 0, sizeof m); hdr(m, 0x24 + 8, 30241, 0); w32(m, 0x20, 2); w32(m, 0x24, ch.id); w32(m, 0x28, pa.id);
		int got = call(fd, m, 0x2c, rep, sizeof rep);
		CHECK(got == 0x24 && r32(rep, 0x20) == 1001);                                    /* anything but a full list of 0x400 ids is refused (recorded) */
		memset(m, 0, sizeof m); hdr(m, 0x1024, 30241, 0); w32(m, 0x20, 0x400); w32(m, 0x24, ch.id); w32(m, 0x28, pa.id);
		got = call(fd, m, 0x1024, rep, sizeof rep);
		CHECK(got == 0x1028 && r32(rep, 0x20) == 0 && r32(rep, 0x24) == 0x400 && r32(rep, 0x28) == pa.id && r32(rep, 0x2c) == 0);
		ws_win_order(c, &ch, 0, 0);
		memset(m, 0, sizeof m); hdr(m, 0x24, 30312, 0); w32(m, 0x20, ch.id); got = call(fd, m, 0x24, rep, sizeof rep);
		CHECK(got == 0x28 && r32(rep, 0x20) == 0 && rep[0x24] == 0);
		ws_win_order(c, &ch, 1, 0); got = call(fd, m, 0x24, rep, sizeof rep); CHECK(got == 0x28 && rep[0x24] == 1);
		ws_win_order(c, &ch, 0, 0);
		w32(m, 0x20, 0x7ffff); got = call(fd, m, 0x24, rep, sizeof rep); CHECK(got == 0x28 && rep[0x24] == 0);
		memset(m, 0, sizeof m); hdr(m, 0x28, 30249, 0); w32(m, 0x20, pa.id); w32(m, 0x24, ch.id); CHECK(rc(fd, m, 0x28) == 0);                                /* a cycle is refused silently */
		memset(m, 0, sizeof m); hdr(m, 0x1024, 30241, 0); w32(m, 0x20, 0x400); w32(m, 0x24, pa.id); got = call(fd, m, 0x1024, rep, sizeof rep); CHECK(got == 0x1028 && r32(rep, 0x28) == 0);
		ws_win_order(c, &pa, 0, 0);
	}

	/* tracking areas (the legacy API AppKit uses): AddTrackingArea, SetTrackingAreasEnabled, RemoveTrackingArea(s), RemoveAllTrackingAreas */
	{
		uint8_t reg[64]; size_t rn = ws_region_serialize(&(ws_rect){ 0, 0, 50, 50 }, 1, reg, sizeof reg);
		ws_win_set_event_mask(c, &w, -1);
		ws_event e; while (ws_conn_next_pushed_event(c, 20, &e)) { }
		uint8_t am[0x50 + 64]; memset(am, 0, sizeof am); hdr(am, 0x50, 30157, 1);
		w32(am, 0x18, 1); am[0x25] = 1; am[0x27] = 1; w32(am, 0x28, (uint32_t)rn); memcpy(am + 0x2c, &WS_NDR, 8);
		w32(am, 0x34, w.id); w32(am, 0x38, (uint32_t)rn); w32(am, 0x3c, 0x77); memcpy(am + 0x50, reg, rn);
		CHECK(rc(fd, am, 0x50 + rn) == 0);                                              /* created under the pointer: entered at once */
		ws_post_mouse_event(c, 5, 40, 50, 0, 0, 0);
		int entered = 0; for (int i = 0; i < 10 && ws_conn_next_pushed_event(c, 100, &e); i++) if (e.type == WS_EV_TRACK_ENTER && e.key == 0x77 && e.wid == w.id) entered = 1;
		CHECK(entered);
		uint8_t ra[0x24]; memset(ra, 0, sizeof ra); hdr(ra, 0x24, 30162, 0); memcpy(ra + 0x18, &WS_NDR, 8); w32(ra, 0x20, w.id);
		CHECK(rc(fd, ra, 0x24) == 0);
		ws_post_mouse_event(c, 5, 120, 100, 0, 0, 0); ws_post_mouse_event(c, 5, 40, 50, 0, 0, 0);
		int again = 0; for (int i = 0; i < 6 && ws_conn_next_pushed_event(c, 60, &e); i++) if (e.type == WS_EV_TRACK_ENTER) again = 1;
		CHECK(!again);                                                                    /* all removed */
		uint8_t rm[0x2c]; memset(rm, 0, sizeof rm); hdr(rm, 0x2c, 30160, 0); memcpy(rm + 0x18, &WS_NDR, 8); w32(rm, 0x20, w.id); w32(rm, 0x24, 0x77);
		CHECK(rc(fd, rm, 0x2c) == 0);
		uint8_t en[0x40 + 8]; memset(en, 0, sizeof en); hdr(en, 0x40, 30164, 1); w32(en, 0x18, 1); en[0x25] = 1; en[0x27] = 1; w32(en, 0x28, 8); memcpy(en + 0x2c, &WS_NDR, 8);
		w32(en, 0x34, w.id); w32(en, 0x38, 1); w32(en, 0x3c, 1); w32(en, 0x40, 0x99); w32(en, 0x44, 0);
		CHECK(rc(fd, en, 0x48) == 0);
		w32(en, 0x34, 0x7ffff); CHECK(rc(fd, en, 0x48) == 1000);
	}

	/* GetDisplaySystemState: the layout of the real state (header, mode records, tail), filled for wsd's display (640x480 in the test) */
	{
		uint8_t q[0x28]; memset(q, 0, sizeof q); hdr(q, 0x28, SLS_MSG_GetDisplaySystemState, 0); memcpy(q + 0x18, &WS_NDR, 8); w32(q, 0x20, 13);
		uint8_t big[4096];
		int dn = call(fd, q, 0x28, big, sizeof big);
		uint32_t blen = r32(big, 0x28);
		CHECK(dn == 0x38 + (int)blen && r32(big, 0x34) == blen);
		const uint8_t *b = big + 0x38;
		uint32_t count = r32(b, 63 * 4), cur = r32(b, 16);
		CHECK(count >= 1 && cur == count - 1 && blen == 64 * 4 + count * 132 + 64 + 3);
		const uint8_t *last = b + 256 + cur * 132;                                       /* the current (native) mode record */
		CHECK(r32(last, 24) == 640 && r32(last, 28) == 480 && r32(last, 40) == 2560 && r32(last, 12) == 0x2000007);
		double dw; memcpy(&dw, b + 32 * 4, 8); CHECK(dw == 640.0);
		CHECK(r32(b, 23 * 4) == 0x12345678);
	}
	ws_server_quit(c);
	printf(failures ? "%d failures\n" : "window extension routines: all checks passed\n", failures);
	return failures != 0;
}
