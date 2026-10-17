/* Event tap registry (decompiled __XPlaceTap, __XPlaceTapOnConnection, __XReleaseEventTap, __XEnableEventTap, __XEventTapIsEnabled, __XGetEventTapList,
 * __XSetEventTapTimeout, __XGetEventTapTimeout, __XSetEventTapOption). The taps are kept per tapping connection and removed when it goes away.
 * Not implemented: handing the events to the tapping process (the tap's reply port); the registry is what the queries observe. */
#include "wsd_priv.h"
#include "ws_evrec.h"
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define MAXTAPS 256
typedef struct { int used; uint32_t id, owner; int pid; uint32_t placement, options, mask; uint64_t target; uint32_t port; int enabled; } tap_t;
static tap_t taps[MAXTAPS];
static uint32_t next_tap = 1;
static float tap_timeout = 1.0f;                           /* inferred default; the setter clamps to 0..10 as the decompile does */

static tap_t *tap_find(uint32_t id) { for (int i = 0; i < MAXTAPS; i++) if (taps[i].used && taps[i].id == id) return &taps[i]; return NULL; }

void sls_tap_owner_cleanup(uint32_t owner) { for (int i = 0; i < MAXTAPS; i++) if (taps[i].used && taps[i].owner == owner) taps[i].used = 0; }

/* Listen-only taps (option bit 0) get every event of a type in their mask: the data of PostEventTapData (decompiled client side, docs/EVENT-TAPS.md) as a notification on the owner's event channel:
 * type 0, sequence, tap id, n, then n bytes = the data stream: token 0, the length of the event, the CGEvent record. Taps that may change the event (not listen-only) are not served yet. */
extern void wsd_push_notification(uint32_t owner, uint32_t type, const uint8_t *data, uint32_t n);
static uint32_t tap_seq;
static int send_tap(tap_t *t, const uint8_t *rec, size_t n)                       /* one event to one tap: returns the sequence number, 0 when it cannot go */
{
	if (!wsd_conn_by_id(t->owner)) return 0;
	uint8_t b[16 + 8 + 512]; uint32_t body = (uint32_t)n + 8; if (body > 512) return 0;
	memset(b, 0, sizeof b);
	uint32_t seq = ++tap_seq; if (!seq) seq = ++tap_seq;
	wr32(b, 0, 0); wr32(b, 4, seq); wr32(b, 8, t->id); wr32(b, 12, body);
	wr32(b, 16, 0); wr32(b, 20, (uint32_t)n);                                  /* token 0 and the event length (native order, as the client reads them raw) */
	memcpy(b + 24, rec, n);
	wsd_push_notification(t->owner, WSD_NOTE_TAP_DATA, b, 16 + 8 + (uint32_t)n);
	return seq;
}
void sls_tap_deliver(int cgtype, const uint8_t *rec, size_t n)
{
	for (int i = 0; i < MAXTAPS; i++) {
		tap_t *t = &taps[i];
		if (!t->used || !t->enabled || !(t->options & 1) || cgtype < 0 || cgtype > 31 || !((t->mask >> cgtype) & 1)) continue;
		send_tap(t, rec, n);
	}
}

/* Active taps (option bit 0 clear) may change or drop key events. A key event is held back in a queue; the head is offered to the first matching tap (in placement order),
 * the tap's client answers with PostFilteredEventTapData style 0 (decompiled post_filtered_event_tap_data): tap id, the sequence it was given, and the surviving events;
 * those continue through the taps placed after it and then reach the windows, no events at all means the event was dropped. A tap that does not answer within the tap
 * timeout is disabled (EventTapSendDataProcessedAck's "did not ACK in time") and the event goes on. Only key down / up events are held (flag changes and the pointer are not). */
#define MAXPEND 64
typedef struct { int key, down; uint32_t after, tap_id, seq; double deadline; int sent; } pend_t;
static pend_t pend[MAXPEND]; static int pn;
static double now_s(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }
static tap_t *next_active(uint32_t after, int cgtype)
{
	tap_t *best = NULL;
	for (int i = 0; i < MAXTAPS; i++) {
		tap_t *t = &taps[i];
		if (!t->used || !t->enabled || (t->options & 1) || t->id <= after || !((t->mask >> cgtype) & 1) || !wsd_conn_by_id(t->owner)) continue;
		if (!best || t->id < best->id) best = t;
	}
	return best;
}
static void pump(void)
{
	while (pn > 0 && !pend[0].sent) {
		pend_t *p = &pend[0]; int cg = p->down ? 10 : 11;
		tap_t *t = next_active(p->after, cg);
		uint32_t seq = 0;
		if (t) {
			uint8_t rec[512]; int cx, cy; ws_cursor_pos(srv, &cx, &cy);
			size_t n = ws_evrec_make_key(rec, sizeof rec, p->down, p->key, ws_server_modifier_flags(srv), (float)cx, (float)cy, 0, 0, 0x0a);
			if (n) seq = send_tap(t, rec, n);
		}
		if (!seq) {                                                                   /* no (more) taps: the event reaches the windows */
			int k = p->key, d = p->down; memmove(pend, pend + 1, (size_t)(--pn) * sizeof *pend);
			ws_server_key_unfiltered(srv, k, d); continue;
		}
		p->tap_id = t->id; p->seq = seq; p->deadline = now_s() + tap_timeout; p->sent = 1;
	}
}
int sls_tap_filter_key(int key, int down)
{
	if (pn == 0 && !next_active(0, down ? 10 : 11)) return 0;
	if (pn >= MAXPEND) return 0;
	pend[pn++] = (pend_t){ .key = key, .down = down };
	pump();
	return 1;
}
void sls_tap_post_result(uint32_t tap_id, uint32_t seq, const uint8_t *data, size_t n)
{
	if (pn == 0 || !pend[0].sent || pend[0].tap_id != tap_id || pend[0].seq != seq) return;     /* a late or stale answer */
	memmove(pend, pend + 1, (size_t)(--pn) * sizeof *pend);
	pend_t surv[8]; int ns = 0;
	for (size_t i = 0; n - i > 7 && ns < 8;) {
		uint32_t tok, l; memcpy(&tok, data + i, 4); memcpy(&l, data + i + 4, 4);
		if (tok != 0 || l > n - i - 8) break;
		ws_evrec r; if (!ws_evrec_parse(data + i + 8, l, &r)) { int ty = ws_evrec_type(&r), kc = ws_evrec_keycode(&r); if ((ty == 10 || ty == 11) && kc >= 0) surv[ns++] = (pend_t){ .key = kc, .down = ty == 10, .after = tap_id }; }
		i += 8 + l;
	}
	if (ns && pn + ns <= MAXPEND) { memmove(pend + ns, pend, (size_t)pn * sizeof *pend); memcpy(pend, surv, (size_t)ns * sizeof *pend); pn += ns; }
	pump();
}
int sls_tap_poll(void)                                                               /* milliseconds until a held event times out, -1 when none is held */
{
	if (pn > 0 && pend[0].sent) {
		tap_t *t = tap_find(pend[0].tap_id);
		if (!t || now_s() >= pend[0].deadline) { if (t) t->enabled = 0; pend[0].sent = 0; pend[0].after = pend[0].tap_id; pump(); }
	}
	if (pn > 0 && pend[0].sent) { double d = pend[0].deadline - now_s(); return d <= 0 ? 0 : (int)(d * 1000) + 1; }
	return -1;
}

/* the tapping connection must still exist for its taps to count (a tap whose owner died is released) */
static void purge(void) { for (int i = 0; i < MAXTAPS; i++) if (taps[i].used && !wsd_conn_by_id(taps[i].owner)) taps[i].used = 0; }

/* PlaceTap (32028) and PlaceTapOnConnection (32029): complex, one port descriptor@0x1c (disposition byte 0x11 at 0x26), NDR@0x28, location@0x30 (< 3),
 * u64@0x34, options@0x3c, event mask@0x40; size 0x44. PlaceTapOnConnection takes the connection id as the first word and taps that connection.
 * Reply 0x2c: return code@0x20, tap id@0x24, accepted mask@0x28. */
static int do_place(conn *c, const uint8_t *buf, size_t len, int on_conn)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	if (!(h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != 0x44 || h->msgh_size != 0x44 || rd32(buf, 0x18) != 1) return reply_simple(c->fd, h, -304);
	if (buf[0x26] != 0x11) return reply_simple(c->fd, h, -300);
	uint32_t place = rd32(buf, 0x30);
	if (place >= 3) return reply_simple(c->fd, h, 1000);
	tap_t *t = NULL; purge();
	for (int i = 0; i < MAXTAPS; i++) if (!taps[i].used) { t = &taps[i]; break; }
	if (!t) return reply_simple(c->fd, h, 1000);
	uint32_t owner = c->id; int pid = c->pid;
	if (on_conn) { conn *o = wsd_conn_by_id(rd32(buf, 0x1c)); if (!o) return reply_simple(c->fd, h, 1007); owner = o->id; pid = o->pid; }
	*t = (tap_t){ .used = 1, .id = next_tap++, .owner = owner, .pid = pid, .placement = place, .options = rd32(buf, 0x3c), .mask = rd32(buf, 0x40), .port = rd32(buf, 0x1c), .enabled = 1 };
	memcpy(&t->target, buf + 0x34, 8);
	uint8_t r[0x2c]; memset(r, 0, sizeof r);
	fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
	memcpy(r + 0x18, &WS_NDR, 8); wr32(r, 0x24, t->id); wr32(r, 0x28, t->mask);
	struct iovec v = { r, sizeof r };
	return ws_ipc_send(c->fd, &v, 1, NULL, 0);
}

static int tap_enabled_flag(const tap_t *t) { return t->enabled; }

int sls_tap_dispatch(conn *c, const uint8_t *buf, size_t len)
{
	const mach_msg_header_t *h = (const mach_msg_header_t *)buf;
	switch (h->msgh_id) {
	case SLS_MSG_EventTapSendDataProcessedAck: {                                     /* status@0x20, processed sequence@0x24, tap id@0x28, size 0x2c; 0 (1007-style 0x3ef for an unknown tap id; id 0 is accepted) (decompiled __XEventTapSendDataProcessedAck) */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != 0x2c || h->msgh_size != 0x2c) return reply_simple(c->fd, h, -304);
		uint32_t id = rd32(buf, 0x28);
		if (id && !tap_find(id)) return reply_simple(c->fd, h, 0x3ef);
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_PlaceTap: return do_place(c, buf, len, 0);
	case SLS_MSG_PlaceTapOnConnection: return do_place(c, buf, len, 1);
	case SLS_MSG_ReleaseEventTap: {                                                  /* tap id@0x20, size 0x24: releases every tap of the same tapping connection (the real one: of the same port) */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != 0x24 || h->msgh_size != 0x24) return reply_simple(c->fd, h, -304);
		purge(); tap_t *t = tap_find(rd32(buf, 0x20));
		if (!t) return reply_simple(c->fd, h, 1007);
		uint32_t owner = t->owner;
		for (int i = 0; i < MAXTAPS; i++) if (taps[i].used && taps[i].owner == owner) taps[i].used = 0;
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_EnableEventTap: {                                                   /* tap id@0x20 (0: all taps), enable@0x24, size 0x28 */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != 0x28 || h->msgh_size != 0x28) return reply_simple(c->fd, h, -304);
		uint32_t id = rd32(buf, 0x20); int en = rd32(buf, 0x24) != 0;
		purge();
		if (id == 0) { for (int i = 0; i < MAXTAPS; i++) if (taps[i].used) taps[i].enabled = en; return reply_simple(c->fd, h, 0); }
		tap_t *t = tap_find(id);
		if (!t) return reply_simple(c->fd, h, 1007);
		t->enabled = en;
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_EventTapIsEnabled: {                                                /* tap id@0x20, size 0x24; reply 0x28 with the flag@0x24 */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != 0x24 || h->msgh_size != 0x24) return reply_simple(c->fd, h, -304);
		purge(); tap_t *t = tap_find(rd32(buf, 0x20));
		if (!t) return reply_simple(c->fd, h, 1007);
		uint8_t r[0x28]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, 8); wr32(r, 0x24, (uint32_t)tap_enabled_flag(t));
		struct iovec v = { r, sizeof r };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_GetEventTapList: {                                                  /* size 0x18; reply complex 0x38: OOL array of 0x34-byte entries, count@0x34 */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != 0x18 || h->msgh_size != 0x18) return reply_simple(c->fd, h, -304);
		purge();
		uint32_t n = 0; for (int i = 0; i < MAXTAPS; i++) if (taps[i].used) n++;
		uint8_t *pl = calloc(n ? n : 1, 0x34); if (!pl) return reply_simple(c->fd, h, 1000);
		uint32_t k = 0;
		for (int i = 0; i < MAXTAPS; i++) if (taps[i].used) {
			uint8_t *e = pl + (size_t)k++ * 0x34; const tap_t *t = &taps[i];
			wr32(e, 0, t->id); wr32(e, 4, t->placement); wr32(e, 8, t->options);
			wr32(e, 0xc, 0); wr32(e, 0x10, t->mask);                                  /* the 64-bit mask with its halves swapped */
			wr32(e, 0x18, (uint32_t)t->pid); wr32(e, 0x1c, (uint32_t)tap_enabled_flag(t));
			memcpy(e + 0x20, &t->target, 8);
		}
		uint8_t m[0x38]; memset(m, 0, sizeof m);
		fill_reply_header((mach_msg_header_t *)m, h, sizeof m, 1);
		wr32(m, 0x18, 1); m[0x24] = 1; m[0x25] = 1; m[0x27] = 1; wr32(m, 0x28, n * 0x34); memcpy(m + 0x2c, &WS_NDR, 8); wr32(m, 0x34, n);
		struct iovec v[2] = { { m, sizeof m }, { pl, n * 0x34 } };
		int rc = ws_ipc_send(c->fd, v, n ? 2 : 1, NULL, 0);
		free(pl);
		return rc;
	}
	case SLS_MSG_SetEventTapTimeout: {                                               /* seconds (float)@0x20, size 0x24; clamped to 0..10 */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != 0x24 || h->msgh_size != 0x24) return reply_simple(c->fd, h, -304);
		float f; memcpy(&f, buf + 0x20, 4);
		if (f != f) f = 0;
		tap_timeout = f > 10.0f ? 10.0f : f < 0.0f ? 0.0f : f;
		return reply_simple(c->fd, h, 0);
	}
	case SLS_MSG_GetEventTapTimeout: {                                               /* size 0x18; reply 0x28 with the float@0x24 */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != 0x18 || h->msgh_size != 0x18) return reply_simple(c->fd, h, -304);
		uint8_t r[0x28]; memset(r, 0, sizeof r);
		fill_reply_header((mach_msg_header_t *)r, h, sizeof r, 0);
		memcpy(r + 0x18, &WS_NDR, 8); memcpy(r + 0x24, &tap_timeout, 4);
		struct iovec v = { r, sizeof r };
		return ws_ipc_send(c->fd, &v, 1, NULL, 0);
	}
	case SLS_MSG_SetEventTapOption: {                                                /* size 0x2c: tap id@0x20, kind@0x24 (0 = logging), value@0x28; only Apple internal builds may do this: 1003 otherwise (recorded) */
		if ((h->msgh_bits & MACH_MSGH_BITS_COMPLEX) || len != 0x2c || h->msgh_size != 0x2c) return reply_simple(c->fd, h, -304);
		return reply_simple(c->fd, h, 0x3eb);
	}
	default: return -2;
	}
}
