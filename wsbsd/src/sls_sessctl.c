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
void sls_sessctl_owner_cleanup(uint32_t owner) { for (int i = 0; i < 64; i++) if (secure_ids[i] == owner) secure_ids[i] = 0; }
static double real_time(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return ts.tv_sec + ts.tv_nsec * 1e-9; }

int sls_sessctl_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	switch (h->msgh_id) {
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
