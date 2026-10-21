/* Window transitions (decompiled from SkyLight): __XNewTransition (30217), __XInvokeTransition (30218), __XReleaseTransition (30219) with new_transition, transitionByID, transitionFinished.
 * New: size 0x38 (not complex), style@0x20, flags@0x24, window@0x28 (0: the whole screen; else it must exist, 1001, and the caller needs rights, 1002), three floats@0x2c (the style's options); the styles
 * 0x10000000 / 2 mean 1, 0x10000001 means 0, 0x10000003 means 9, any other above 9 gives 1001; style 0 makes no transition (id 0). Reply 0x28: id@0x24. The transition is dropped 2 s after it was
 * created unless it is invoked. Invoke: size 0x28, id@0x20, duration (float)@0x24; an unknown id gives 1003; the transition ends after the duration. Release: size 0x24, id@0x20, 1003 for an unknown one.
 * Whenever a transition ends (invoked, released, timed out) its creator is told with notification 0x6a4 (the id); a creator that goes away takes its transitions with it. The visual effect itself is not
 * rendered: the compositor has no transition stage yet. */
#include "wsd_priv.h"
#include <string.h>
#include <time.h>

#define MAX_TRANSITIONS 64
#define NOTE_TRANSITION_DONE 0x6a4
static struct { int used; uint32_t id, owner, style, flags, window; float opt[3]; double deadline; } tr[MAX_TRANSITIONS];
static uint32_t next_id = 1;
extern void wsd_push_notification(uint32_t owner, uint32_t type, const uint8_t *data, uint32_t n);

static double now_s(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return ts.tv_sec + ts.tv_nsec * 1e-9; }
static int find(uint32_t id) { for (int i = 0; i < MAX_TRANSITIONS; i++) if (tr[i].used && tr[i].id == id) return i; return -1; }
static void finish(int i, int notify)
{
	uint32_t id = tr[i].id, owner = tr[i].owner; memset(&tr[i], 0, sizeof tr[i]);
	if (notify && owner) { uint8_t b[4]; wr32(b, 0, id); wsd_push_notification(owner, NOTE_TRANSITION_DONE, b, 4); }
}
void sls_transition_owner_cleanup(uint32_t owner) { for (int i = 0; i < MAX_TRANSITIONS; i++) if (tr[i].used && tr[i].owner == owner) finish(i, 0); }
int sls_transition_poll(void)                                                  /* ends the transitions that are due; milliseconds until the next deadline, -1 when none */
{
	double now = now_s(), next = -1;
	for (int i = 0; i < MAX_TRANSITIONS; i++) {
		if (!tr[i].used) continue;
		if (tr[i].deadline <= now) { finish(i, 1); continue; }
		if (next < 0 || tr[i].deadline < next) next = tr[i].deadline;
	}
	if (next < 0) return -1;
	double ms = (next - now) * 1000.0 + 1; return ms > 1000 ? 1000 : (int)ms;
}

int sls_transition_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (h->msgh_id == 30217) {
		if (!simple_ok(h, len, 0x38)) return reply_simple(c->fd, h, -304);
		uint32_t style = rd32(buf, 0x20), flags = rd32(buf, 0x24), wid = rd32(buf, 0x28);
		if (wid) { if (!ws_window_exists(srv, wid)) return reply_simple(c->fd, h, 1001); if (!holds_rights(c, wid)) return reply_simple(c->fd, h, 1002); }
		if (style > 9) {
			if (style == 0x10000000 || style == 0x10000002) style = 1; else if (style == 0x10000001) style = 0; else if (style == 0x10000003) style = 9; else return reply_simple(c->fd, h, 1001);
		}
		uint32_t id = 0;
		if (style) {
			int slot = -1; for (int i = 0; i < MAX_TRANSITIONS; i++) if (!tr[i].used) { slot = i; break; }
			if (slot < 0) return reply_simple(c->fd, h, 1004);
			memset(&tr[slot], 0, sizeof tr[slot]); tr[slot].used = 1; tr[slot].id = id = next_id++; tr[slot].owner = c->id; tr[slot].style = style; tr[slot].flags = flags; tr[slot].window = wid;
			memcpy(tr[slot].opt, buf + 0x2c, 12); tr[slot].deadline = now_s() + 2.0;
		}
		uint8_t r[0x28]; memset(r, 0, sizeof r); fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0); memcpy(r + 0x18, &WS_NDR, 8); wr32(r, 0x24, id);
		return ws_ipc_send(c->fd, &(struct iovec){ r, sizeof r }, 1, NULL, 0);
	}
	if (h->msgh_id == 30218) {
		if (!simple_ok(h, len, 0x28)) return reply_simple(c->fd, h, -304);
		int i = find(rd32(buf, 0x20)); if (i < 0) return reply_simple(c->fd, h, 1003);
		float d; memcpy(&d, buf + 0x24, 4); if (!(d > 0)) d = 0;
		tr[i].deadline = now_s() + d; if (d == 0) finish(i, 1);
		return reply_simple(c->fd, h, 0);
	}
	if (h->msgh_id == 30219) {
		if (!simple_ok(h, len, 0x24)) return reply_simple(c->fd, h, -304);
		int i = find(rd32(buf, 0x20)); if (i < 0) return reply_simple(c->fd, h, 1003);
		finish(i, 1); return reply_simple(c->fd, h, 0);
	}
	return -2;
}
