/* Session control routines (decompiled from SkyLight): __XCreateSession (29001), __XReleaseSession (29006), __XSwitchConsoleToSession (29007), __XSetSessionScreenLockWindow (29011),
 * __XSetSessionSleepWindows (29012), __XSetSessionSwitchCubeAnimation (29013), __XSetSessionClientDictionary (29015). The session table lives here: session 256 (the login session, on the
 * console) exists from the start; CreateSession adds one (reply 0x28 with the id@0x24), Release removes it, SwitchConsole moves the console, the lock window / sleep shield and auth windows
 * are kept per session (a window id that does not exist gives 1000 for the sleep windows, nothing for the lock window, as decompiled), the cube flag is global, the client dictionary is kept
 * as the serialized bytes the client sent (1000 for an unknown session).
 * Requests: Create complex, 2 descriptors-worth (count@0x18 = 2), size 0x50, byte@0x27 and @0x37 = 1, the two sizes @0x28 = @0x44 and @0x38 = @0x48 (else -300); Release / SwitchConsole 0x2c (session@0x20);
 * ScreenLockWindow 0x28 (session@0x20, window@0x24); SleepWindows 0x2c (session@0x20, shield@0x24, auth@0x28); Cube 0x24 (byte@0x20); ClientDictionary complex 1, size 0x44, byte@0x27 = 1,
 * size@0x28 = @0x40, session@0x34, the bytes after the header. */
#include "wsd_priv.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>
extern int wsd_screen_w, wsd_screen_h;

#define MAX_SESSIONS 16
static struct { int used; uint32_t id; uint32_t lock_win, shield_win, auth_win; uint8_t *dict; uint32_t dict_len; } sess[MAX_SESSIONS] = { { 1, 256, 0, 0, 0, NULL, 0 } };
static uint32_t console_session = 256, next_session = 257;
static int cube_animation;

static int sidx(uint32_t id) { for (int i = 0; i < MAX_SESSIONS; i++) if (sess[i].used && sess[i].id == id) return i; return -1; }
static int sel(uint32_t id) { return id ? sidx(id) : sidx(256); }                    /* selector 0: the caller's own (here the login) session */

uint32_t sls_session_console(void) { return console_session; }
int sls_session_count(void) { int n = 0; for (int i = 0; i < MAX_SESSIONS; i++) n += sess[i].used; return n; }
int sls_session_cube_enabled(void) { return cube_animation; }
uint32_t sls_session_lock_window(uint32_t id) { int i = sidx(id); return i < 0 ? 0 : sess[i].lock_win; }
const uint8_t *sls_session_client_dict(uint32_t id, uint32_t *len) { int i = sidx(id); if (i < 0) return NULL; *len = sess[i].dict_len; return sess[i].dict; }

static uint64_t last_deactivated; static float unresponsive_timeout = 1.0f; static uint32_t secure_ids[64];       /* the connections that hold secure event input */
int sls_secure_input_active(void) { for (int i = 0; i < 64; i++) if (secure_ids[i]) return 1; return 0; }
static void upd_drop(uint32_t owner);
void sls_sessctl_owner_cleanup(uint32_t owner) { for (int i = 0; i < 64; i++) if (secure_ids[i] == owner) secure_ids[i] = 0; upd_drop(owner); }
static double real_time(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return ts.tv_sec + ts.tv_nsec * 1e-9; }

/* Per-connection update disabling (disable_update_for_connection / common_reenable_update, Updater.cc): the count (+0xb4) goes up with every Disable and down with every Reenable (never below 0);
 * the strict count (+0xb8) does the same and remembers when it left 0; while the count is above 0 the connection's flushes are held back as one rectangle per window and applied when it
 * returns to 0 (the real server accumulates the update shape and schedules all displays); a connection that stays disabled longer than gWSDisableUpdateTimeout is re-enabled by the server
 * (disable_update_timeout; the default value of that global is not read from the binary, 1 s is used). */
#define MAX_UPD 32
#define MAX_HELD 16
typedef struct { uint32_t wid; int whole; ws_rect r; } held_rect;
static struct { uint32_t owner; int disabled, strict; double since, deadline; held_rect held[MAX_HELD]; } upd[MAX_UPD];
static double disable_update_timeout = 1.0;

static int upd_idx(uint32_t owner, int create)
{
	int free_i = -1;
	for (int i = 0; i < MAX_UPD; i++) { if (upd[i].owner == owner) return i; if (!upd[i].owner && free_i < 0) free_i = i; }
	if (!create || free_i < 0) return -1;
	memset(&upd[free_i], 0, sizeof upd[free_i]); upd[free_i].owner = owner; return free_i;
}
static void upd_release(int i)
{
	for (int k = 0; k < MAX_HELD; k++) if (upd[i].held[k].wid) {
		if (upd[i].held[k].whole) ws_window_damage(srv, upd[i].held[k].wid, NULL); else ws_window_flush_rect(srv, upd[i].held[k].wid, &upd[i].held[k].r);
	}
	memset(&upd[i], 0, sizeof upd[i]); wsd_dirty = 1;
}
static void upd_reenable(uint32_t owner)                                       /* common_reenable_update(conn, true) */
{
	int i = upd_idx(owner, 0); if (i < 0) return;
	if (upd[i].strict > 0) upd[i].strict--;
	if (upd[i].disabled > 0 && --upd[i].disabled == 0) upd_release(i);
}
static void upd_expire(void)                                                   /* disable_update_timeout: the server forces updates back on */
{
	double now = real_time();
	for (int i = 0; i < MAX_UPD; i++) if (upd[i].owner && upd[i].disabled > 0 && now >= upd[i].deadline) upd_release(i);
}
static void upd_drop(uint32_t owner) { int i = upd_idx(owner, 0); if (i >= 0) memset(&upd[i], 0, sizeof upd[i]); }   /* the connection went away: nothing left to apply */
int sls_updates_disabled(uint32_t owner) { upd_expire(); int i = upd_idx(owner, 0); return i >= 0 && upd[i].disabled > 0; }
int sls_updates_hold(uint32_t owner, uint32_t wid, const ws_rect *r)           /* 1 = the flush is kept until the connection's updates are enabled again (r NULL: the whole window) */
{
	upd_expire();
	int i = upd_idx(owner, 0); if (i < 0 || upd[i].disabled <= 0) return 0;
	int slot = -1;
	for (int k = 0; k < MAX_HELD; k++) { if (upd[i].held[k].wid == wid) { slot = k; break; } if (!upd[i].held[k].wid && slot < 0) slot = k; }
	if (slot < 0) { for (int k = 0; k < MAX_HELD; k++) if (upd[i].held[k].wid) { upd[i].held[k].whole = 1; } return 1; }   /* table full: the oldest windows are repainted whole */
	held_rect *e = &upd[i].held[slot];
	if (!e->wid) { e->wid = wid; e->whole = r == NULL; if (r) e->r = *r; }
	else if (!e->whole) {
		if (!r) e->whole = 1;
		else {
			int32_t x0 = e->r.x < r->x ? e->r.x : r->x, y0 = e->r.y < r->y ? e->r.y : r->y;
			int32_t x1 = e->r.x + e->r.w > r->x + r->w ? e->r.x + e->r.w : r->x + r->w, y1 = e->r.y + e->r.h > r->y + r->h ? e->r.y + e->r.h : r->y + r->h;
			e->r = (ws_rect){ x0, y0, x1 - x0, y1 - y0 };
		}
	}
	return 1;
}

int sls_sessctl_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	switch (h->msgh_id) {
	case 30036: {                                                                 /* __XDisableUpdateForConnection: header only (0x18); count + 1, strict count + 1 (time of the first), timeout armed; reply 0 */
		if (h->msgh_bits & MACH_MSGH_BITS_COMPLEX || h->msgh_size != 0x18 || len != 0x18) return reply_simple(c->fd, h, -304);
		int i = upd_idx(c->id, 1);
		if (i >= 0) {
			upd[i].disabled++; if (upd[i].strict++ == 0) upd[i].since = real_time();
			upd[i].deadline = real_time() + disable_update_timeout;
		}
		return reply_simple(c->fd, h, 0);
	}
	case 30038: {                                                                 /* __XReenableUpdateForConnectionSync: complex, one descriptor (the port told once the displays updated), size 0x28; descriptor disposition@0x26 must be 0x11 (else -300), wrong header -304; counts - 1, held flushes applied at 0; reply 0 */
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || rd32(buf, 0x18) != 1 || h->msgh_size != 0x28 || len < 0x28) return reply_simple(c->fd, h, -304);
		if (buf[0x26] != 0x11 || buf[0x27] != 0) return reply_simple(c->fd, h, -300);
		upd_reenable(c->id);
		return reply_simple(c->fd, h, 0);
	}
	case 30087: {                                                                 /* __XSetSecureEventInput: flag@0x20; the connection's bit 0 of its flags is set / cleared and the system's secure input follows (any connection holding it) */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		int on = rd32(buf, 0x20) != 0;
		sls_sessctl_owner_cleanup(c->id); if (on) for (int i = 0; i < 64; i++) if (!secure_ids[i]) { secure_ids[i] = c->id; break; }
		return reply_simple(c->fd, h, 0);
	}
	case 30196:                                                                   /* __XSetLastDeactivated: 64-bit value@0x20 of the session's event state */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		memcpy(&last_deactivated, buf + 0x20, 8); return reply_simple(c->fd, h, 0);
	case 30206: {                                                                 /* __XEventSetAppIsUnresponsiveNotificationTimeout: float@0x20, at least 1 second */
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		float f; memcpy(&f, buf + 0x20, 4); unresponsive_timeout = f < 1.0f ? 1.0f : f; return reply_simple(c->fd, h, 0);
	}
	case 30207: {                                                                 /* __XEventAppUnresponsiveStatus: PSN@0x20 (hi, lo); reply 0x2c: seconds without an answer (float@0x24, 0 for a responsive one), flags@0x28; 1001 for an unknown process */
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		if (!wsd_conn_by_psn(rd32(buf, 0x20), rd32(buf, 0x24))) return reply_simple(c->fd, h, 1001);
		uint8_t r[0x2c]; memset(r, 0, sizeof r); fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0); memcpy(r + 0x18, &WS_NDR, 8);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case 30031: {                                                                  /* __XSetWindowWarp: complex, one OOL of floats (x y u v per mesh point), size 0x44: OOL size@0x28, window@0x34, columns@0x38, rows@0x3c, float count@0x40 (= size / 4 = columns * rows * 4, both <= 0x800, else 1000; a float of 2.1e9 or more gives 1000); the mesh follows the header; reply 0 */
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x44 || len < 0x44 || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
		uint32_t osz = rd32(buf, 0x28), cols = rd32(buf, 0x38), rows = rd32(buf, 0x3c);
		if (buf[0x27] != 1 || (osz >> 2) != rd32(buf, 0x40)) return reply_simple(c->fd, h, -300);
		if (len < 0x44 + (size_t)osz) return reply_simple(c->fd, h, -304);
		if (cols > 0x800 || rows > 0x800 || (osz >> 2) != cols * rows * 4) return reply_simple(c->fd, h, 1000);
		const float *mesh = (const float *)(const void *)(buf + 0x44); uint32_t nf = osz >> 2;
		for (uint32_t i = 0; i < nf; i++) { float v; memcpy(&v, buf + 0x44 + 4 * (size_t)i, 4); if (v >= 2.1474836e9f || v <= -2.1474836e9f || v != v) return reply_simple(c->fd, h, 1000); }
		(void)mesh;
		uint32_t wid = rd32(buf, 0x34);
		if (nf >= 16 && ws_window_exists(srv, wid)) { float *m = malloc(osz); if (m) { memcpy(m, buf + 0x44, osz); ws_set_window_warp(srv, wid, (int)cols, (int)rows, m); free(m); } }
		else if (ws_window_exists(srv, wid)) ws_set_window_warp(srv, wid, 0, 0, NULL);
		return reply_simple(c->fd, h, 0);
	}
	case 30032: {                                                                  /* __XSetWindowTransformList: complex, two OOLs, size 0x54: window ids (size@0x28, count@0x4c = size / 4) and transforms (size@0x38, count@0x50 = size / 0x18: a b c d tx ty floats each); both follow the header; -300 for a mismatch */
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x54 || len < 0x54 || rd32(buf, 0x18) != 2) return reply_simple(c->fd, h, -304);
		uint32_t a = rd32(buf, 0x28), b = rd32(buf, 0x38);
		if (buf[0x27] != 1 || buf[0x37] != 1 || (a >> 2) != rd32(buf, 0x4c) || b / 0x18 != rd32(buf, 0x50) ) return reply_simple(c->fd, h, -300);
		if (len < 0x54 + (size_t)a + b) return reply_simple(c->fd, h, -304);
		for (uint32_t i = 0; i < a / 4 && i < b / 0x18; i++) { float m[6]; memcpy(m, buf + 0x54 + a + 0x18 * (size_t)i, 24); ws_set_window_transform(srv, rd32(buf + 0x54, 4 * i), m); }
		return reply_simple(c->fd, h, 0);
	}
	case 30035: {                                                                  /* __XSetWindowListBrightness: complex, two OOLs, size 0x4c: window ids (size@0x28, count@0x44) and brightness floats (size@0x38, count@0x48), both after the header; a window takes the brightness of its place in the list; reply 0, -300 for a mismatch */
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x4c || len < 0x4c || rd32(buf, 0x18) != 2) return reply_simple(c->fd, h, -304);
		uint32_t a = rd32(buf, 0x28), b = rd32(buf, 0x38);
		if (buf[0x27] != 1 || buf[0x37] != 1 || (a >> 2) != rd32(buf, 0x44) || (b >> 2) != rd32(buf, 0x48) ) return reply_simple(c->fd, h, -300);
		if (len < 0x4c + (size_t)a + b) return reply_simple(c->fd, h, -304);
		for (uint32_t i = 0; i < a / 4 && i < b / 4; i++) { float f; memcpy(&f, buf + 0x4c + a + 4 * (size_t)i, 4); ws_set_window_brightness(srv, rd32(buf + 0x4c, 4 * i), f); }
		return reply_simple(c->fd, h, 0);
	}
	case 29034: case 30509: case 30510: case 30512: case 30513: case 30535: case 30508: {   /* display presets of the one display (id 1): __XDisplayGetActivePresetIndex, GetFactoryDefaultPresetIndex, GetPresetCount (request 0x24: display@0x20), IsPresetValid / IsPresetWritable (0x28: display@0x20, index@0x24), GetPreferHDR10 (0x24); reply 0x28 with the value@0x24; SetActivePresetIndex (0x28) answers a code. One factory preset, index 0, valid, not writable, active; HDR10 not preferred; 1006 for another display, 1000 for an index there is not */
		int two = h->msgh_id == 30512 || h->msgh_id == 30513 || h->msgh_id == 30508;
		if (!simple_ok(h, len, two ? 0x28 : 0x24)) return reply_simple(c->fd, h, -304);
		if (rd32(buf, 0x20) != 1) return reply_simple(c->fd, h, 1006);
		uint32_t idx = two ? rd32(buf, 0x24) : 0;
		if (h->msgh_id == 30508) return reply_simple(c->fd, h, idx == 0 ? 0 : 1000);
		uint32_t v = h->msgh_id == 30510 ? 1 : h->msgh_id == 30512 ? idx == 0 : 0;
		uint8_t r[0x28]; memset(r, 0, sizeof r); fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0); memcpy(r + 0x18, &WS_NDR, 8); wr32(r, 0x24, v);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case 30044: case 30045: {                                                      /* __XGetPerformanceTotalUpdateCount: reply 0x34: 64-bit count@0x24 (presented frames), time double@0x2c;  __XGetPerformanceUpdateCountPerDisplay: reply 0x22c: 128 counters@0x24 (display 0 = all frames), time@0x224 */
		if (!simple_ok(h, len, 0x18)) return reply_simple(c->fd, h, -304);
		uint64_t n = ws_fps_total(); double t = real_time();
		uint8_t r[0x22c]; memset(r, 0, sizeof r); size_t sz = h->msgh_id == 30044 ? 0x34 : 0x22c;
		fill_reply_header((mach_msg_header_t *)r, h, (uint32_t)sz, 0); memcpy(r + 0x18, &WS_NDR, 8);
		if (h->msgh_id == 30044) { memcpy(r + 0x24, &n, 8); memcpy(r + 0x2c, &t, 8); } else { uint32_t n32 = (uint32_t)n; memcpy(r + 0x24, &n32, 4); memcpy(r + 0x224, &t, 8); }
		return ws_ipc_send(c->fd, &(struct iovec){ r, sz }, 1, NULL, 0);
	}
	case 30112: {                                                                  /* __XZoomTransformPoint: unzoom flag@0x20, x@0x24 y@0x28 (ints); without zoom the point maps to itself (reply 0x2c: x@0x24 y@0x28); 1000 for a point on no display */
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		int32_t x = (int32_t)rd32(buf, 0x24), y = (int32_t)rd32(buf, 0x28);
		if (rd32(buf, 0x20) == 0 && (x < 0 || y < 0 || x >= wsd_screen_w || y >= wsd_screen_h)) return reply_simple(c->fd, h, 1000);
		uint8_t r[0x2c]; memset(r, 0, sizeof r); fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0); memcpy(r + 0x18, &WS_NDR, 8); wr32(r, 0x24, (uint32_t)x); wr32(r, 0x28, (uint32_t)y);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case 29001: {
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size != 0x50 || len < 0x50 || rd32(buf, 0x18) != 2) return reply_simple(c->fd, h, -304);
		if (buf[0x27] != 1 || buf[0x37] != 1 || rd32(buf, 0x28) != rd32(buf, 0x44) || rd32(buf, 0x38) != rd32(buf, 0x48)) return reply_simple(c->fd, h, -300);
		int f = -1; for (int i = 0; i < MAX_SESSIONS; i++) if (!sess[i].used) { f = i; break; }
		if (f < 0) return reply_simple(c->fd, h, 1001);
		memset(&sess[f], 0, sizeof sess[f]); sess[f].used = 1; sess[f].id = next_session++;
		uint8_t r[0x28]; memset(r, 0, sizeof r); fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, 8); wr32(r, 0x24, sess[f].id);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	case 29006: case 29007: {
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		int i = sidx(rd32(buf, 0x20));
		if (i >= 0 && h->msgh_id == 29006 && sess[i].id != 256) { free(sess[i].dict); if (console_session == sess[i].id) console_session = 256; memset(&sess[i], 0, sizeof sess[i]); }
		else if (i >= 0 && h->msgh_id == 29007) console_session = sess[i].id;
		return reply_simple(c->fd, h, 0);
	}
	case 29011: {
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		int i = sel(rd32(buf, 0x20)); uint32_t w = rd32(buf, 0x24);
		if (i >= 0 && (w == 0 || ws_window_exists(srv, w))) sess[i].lock_win = w;
		return reply_simple(c->fd, h, 0);
	}
	case 29012: {
		if (!simple_ok(h, len, 0x2c)) return reply_simple(c->fd, h, -304);
		int i = sel(rd32(buf, 0x20)); uint32_t sh = rd32(buf, 0x24), au = rd32(buf, 0x28);
		if (i < 0) return reply_simple(c->fd, h, 0);
		if ((sh && !ws_window_exists(srv, sh)) || (au && !ws_window_exists(srv, au))) return reply_simple(c->fd, h, 1000);
		sess[i].shield_win = sh; sess[i].auth_win = au;
		return reply_simple(c->fd, h, 0);
	}
	case 29013:
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		cube_animation = buf[0x20] != 0;
		return reply_simple(c->fd, h, 0);
	case 29015: {
		if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || h->msgh_size < 0x44 || len < 0x44 || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
		uint32_t n = rd32(buf, 0x28);
		if (buf[0x27] != 1 || n != rd32(buf, 0x40) || len < 0x44 + (size_t)n) return reply_simple(c->fd, h, -300);
		int i = sidx(rd32(buf, 0x34)); if (i < 0) return reply_simple(c->fd, h, 1000);
		free(sess[i].dict); sess[i].dict = n ? malloc(n) : NULL; sess[i].dict_len = sess[i].dict ? n : 0; if (sess[i].dict) memcpy(sess[i].dict, buf + 0x44, n);
		return reply_simple(c->fd, h, 0);
	}
	}
	return -2;
}
