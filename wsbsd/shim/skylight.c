/* SkyLight client shim: the SLS/CGS C API over wsbsd's wire client (src/client.c). One connection per process, created on first use. */
#include "SkyLight.h"
#include "ws_client.h"
#include <stdlib.h>
#include <string.h>

#define MAXWIN 1024
static ws_conn *conn;
static struct { int used; CGSWindowID wid; ws_win w; int level; } wins[MAXWIN];

static ws_conn *get_conn(void) { if (!conn) conn = ws_connect(NULL); return conn; }
static int slot_of(CGSWindowID wid) { for (int i = 0; i < MAXWIN; i++) if (wins[i].used && wins[i].wid == wid) return i; return -1; }
/* a window id the shim did not create (or already released) is still sent to the server, which answers as the real one does */
static ws_win *handle(CGSWindowID wid, ws_win *tmp) { int s = slot_of(wid); if (s >= 0) return &wins[s].w; memset(tmp, 0, sizeof *tmp); tmp->id = wid; return tmp; }

struct CGSRegion { SLRect r; };

int SLSMainConnectionID(void) { ws_conn *c = get_conn(); return c ? ws_conn_id(c) : 0; }
CGError SLSNewConnection(int unused, CGSConnectionID *cid) { (void)unused; ws_conn *c = get_conn(); if (!c) return 1000; *cid = ws_conn_id(c); return 0; }
CGError SLSReleaseConnection(CGSConnectionID cid) { (void)cid; return 0; }

CGError SLSNewRegionWithRect(const SLRect *rect, CGSRegionRef *out)
{
	if (!rect || !out) return 1001;
	struct CGSRegion *r = malloc(sizeof *r);
	if (!r) return 1000;
	r->r = *rect; *out = r;
	return 0;
}
CGError CGSNewRegionWithRect(const SLRect *rect, CGSRegionRef *out) { return SLSNewRegionWithRect(rect, out); }
CGError CGSReleaseRegion(CGSRegionRef region) { free(region); return 0; }

CGError SLSNewWindow(CGSConnectionID cid, int type, float x, float y, CGSRegionRef region, CGSWindowID *wid)
{
	(void)cid; (void)type;
	ws_conn *c = get_conn();
	if (!c || !region || !wid) return 1001;
	int slot = -1;
	for (int i = 0; i < MAXWIN && slot < 0; i++) if (!wins[i].used) slot = i;
	if (slot < 0) return 1000;
	ws_rect f = { (int)x, (int)y, (int)region->r.w, (int)region->r.h };
	if (ws_win_create(c, f, 0, &wins[slot].w)) return 1000;
	wins[slot].used = 1; wins[slot].wid = wins[slot].w.id; *wid = wins[slot].wid;
	return 0;
}

CGError SLSReleaseWindow(CGSConnectionID cid, CGSWindowID wid)
{
	(void)cid;
	ws_win tmp; ws_win *w = handle(wid, &tmp); int s = slot_of(wid);
	int rc = ws_win_release(get_conn(), w);
	if (s >= 0) wins[s].used = 0;
	return rc ? 1000 : 0;
}

CGError SLSOrderWindow(CGSConnectionID cid, CGSWindowID wid, int mode, CGSWindowID relative)
{
	(void)cid;
	ws_win tmp; ws_win *w = handle(wid, &tmp);
	int rc = ws_win_order(get_conn(), w, mode, relative);
	return rc;
}

CGError SLSMoveWindow(CGSConnectionID cid, CGSWindowID wid, const SLPoint *o)
{
	(void)cid;
	ws_win tmp; ws_win *w = handle(wid, &tmp);
	if (!o) return 1001;
	return ws_win_move(get_conn(), w, (int)o->x, (int)o->y);
}

CGError SLSSetWindowLevel(CGSConnectionID cid, CGSWindowID wid, int level)
{
	(void)cid;
	ws_win tmp; ws_win *w = handle(wid, &tmp);
	return ws_win_set_level(get_conn(), w, level);
}
CGError SLSGetWindowLevel(CGSConnectionID cid, CGSWindowID wid, int *level) { (void)cid; ws_win t; return ws_win_get_level(get_conn(), handle(wid, &t), level); }
CGError SLSSetWindowAlpha(CGSConnectionID cid, CGSWindowID wid, float a) { (void)cid; ws_win t; return ws_win_alpha(get_conn(), handle(wid, &t), a); }
CGError SLSGetWindowAlpha(CGSConnectionID cid, CGSWindowID wid, float *a) { (void)cid; ws_win t; return ws_win_get_alpha(get_conn(), handle(wid, &t), a); }

CGError SLSGetWindowBounds(CGSConnectionID cid, CGSWindowID wid, SLRect *b)
{
	(void)cid;
	ws_win tmp; ws_win *w = handle(wid, &tmp);
	if (!b) return 1001;
	ws_rect r; int rc = ws_win_get_bounds(get_conn(), w, &r);
	if (rc) return rc;
	b->x = r.x; b->y = r.y; b->w = r.w; b->h = r.h;
	return 0;
}

CGError SLSGetWindowOwner(CGSConnectionID cid, CGSWindowID wid, CGSConnectionID *owner)
{
	(void)cid;
	ws_win tmp; ws_win *w = handle(wid, &tmp); int rights = 0, own = 0;
	if (!owner) return 1001;
	int rc = ws_win_get_owner(get_conn(), w, &own, &rights);
	if (rc) return rc;
	*owner = own;
	return 0;
}

CGError SLSWindowIsOrderedIn(CGSConnectionID cid, CGSWindowID wid, unsigned char *out)
{
	(void)cid; ws_win t; int v = 0;
	if (!out) return 1001;
	int rc = ws_win_is_ordered_in(get_conn(), handle(wid, &t), &v);
	if (!rc) *out = (unsigned char)v;
	return rc;
}
CGError SLSGetWindowCount(CGSConnectionID cid, CGSConnectionID owner, int *count) { (void)cid; if (!count) return 1001; int n = ws_win_count(get_conn(), owner); if (n < 0) return 1000; *count = n; return 0; }
CGError SLSGetOnScreenWindowCount(CGSConnectionID cid, CGSConnectionID owner, int *count) { (void)cid; if (!count) return 1001; int n = ws_win_onscreen_count(get_conn(), owner); if (n < 0) return 1000; *count = n; return 0; }
CGError SLSSetWindowSubLevel(CGSConnectionID cid, CGSWindowID wid, int sub) { (void)cid; ws_win t; return ws_win_set_sublevel(get_conn(), handle(wid, &t), sub); }
int SLSGetWindowSubLevel(CGSConnectionID cid, CGSWindowID wid) { (void)cid; ws_win t; int v = 0; return ws_win_get_sublevel(get_conn(), handle(wid, &t), &v) ? 0 : v; }
CGError SLSSetWindowEventMask(CGSConnectionID cid, CGSWindowID wid, unsigned mask) { (void)cid; ws_win t; return ws_win_set_event_mask(get_conn(), handle(wid, &t), (int)mask); }
CGError SLSGetWindowEventMask(CGSConnectionID cid, CGSWindowID wid, unsigned *mask) { (void)cid; ws_win t; int v = 0; if (!mask) return 1001; int rc = ws_win_get_event_mask(get_conn(), handle(wid, &t), &v); if (!rc) *mask = (unsigned)v; return rc; }
CGError SLSSetWindowBackgroundBlurRadius(CGSConnectionID cid, CGSWindowID wid, int radius) { (void)cid; ws_win t; return ws_win_blur(get_conn(), handle(wid, &t), radius); }
