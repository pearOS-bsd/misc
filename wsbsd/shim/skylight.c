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
	int s = slot_of(wid);
	if (s < 0) return 1002;
	ws_win_release(get_conn(), &wins[s].w); wins[s].used = 0;
	return 0;
}

CGError SLSOrderWindow(CGSConnectionID cid, CGSWindowID wid, int mode, CGSWindowID relative)
{
	(void)cid;
	int s = slot_of(wid);
	if (s < 0) return 1002;
	return ws_win_order(get_conn(), &wins[s].w, mode, relative) ? 1000 : 0;
}

CGError SLSMoveWindow(CGSConnectionID cid, CGSWindowID wid, const SLPoint *o)
{
	(void)cid;
	int s = slot_of(wid);
	if (s < 0 || !o) return 1002;
	return ws_win_move(get_conn(), &wins[s].w, (int)o->x, (int)o->y) ? 1000 : 0;
}

CGError SLSSetWindowLevel(CGSConnectionID cid, CGSWindowID wid, int level)
{
	(void)cid;
	int s = slot_of(wid);
	if (s < 0) return 1002;
	/* the level goes through SetWindowLevel (30012); the client library exposes it at creation only, so use the raw request */
	return ws_win_set_level(get_conn(), &wins[s].w, level) ? 1000 : 0;
}
CGError SLSGetWindowLevel(CGSConnectionID cid, CGSWindowID wid, int *level) { (void)cid; int s = slot_of(wid); return s < 0 ? 1002 : (ws_win_get_level(get_conn(), &wins[s].w, level) ? 1000 : 0); }
CGError SLSSetWindowAlpha(CGSConnectionID cid, CGSWindowID wid, float a) { (void)cid; int s = slot_of(wid); return s < 0 ? 1002 : (ws_win_alpha(get_conn(), &wins[s].w, a) ? 1000 : 0); }
CGError SLSGetWindowAlpha(CGSConnectionID cid, CGSWindowID wid, float *a) { (void)cid; int s = slot_of(wid); return s < 0 ? 1002 : (ws_win_get_alpha(get_conn(), &wins[s].w, a) ? 1000 : 0); }

CGError SLSGetWindowBounds(CGSConnectionID cid, CGSWindowID wid, SLRect *b)
{
	(void)cid;
	int s = slot_of(wid);
	if (s < 0 || !b) return 1002;
	ws_rect r;
	if (ws_win_get_bounds(get_conn(), &wins[s].w, &r)) return 1000;
	b->x = r.x; b->y = r.y; b->w = r.w; b->h = r.h;
	return 0;
}

CGError SLSGetWindowOwner(CGSConnectionID cid, CGSWindowID wid, CGSConnectionID *owner)
{
	(void)cid;
	int s = slot_of(wid), rights = 0, own = 0;
	if (s < 0 || !owner) return 1002;
	if (ws_win_get_owner(get_conn(), &wins[s].w, &own, &rights)) return 1000;
	*owner = own;
	return 0;
}
