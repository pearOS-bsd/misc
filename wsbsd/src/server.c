#include "ws.h"
#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>
#include <string.h>
#include <math.h>

typedef struct {
	ws_wid id;
	ws_rect frame;
	int level;
	float alpha;
	int filter;                     /* SetWindowCIFilter: 2 = CIColorInvert (rendered), others kept only */
	float xf[6]; int has_xf;        /* SetWindowTransform: a b c d tx ty about the window centre (software compositor) */
	float *mesh; int mcols, mrows;      /* SetWindowWarp: a mesh of mcols x mrows points, 4 floats each: srcX srcY (pixels in the window) dstX dstY (screen); both y axes point up, the origin is the bottom left corner (decompiled Dock, genie) */
	ws_rect *cap_excl; int ncap_excl;   /* SetWindowCaptureExcludeShape: window-relative rectangles left out of screen captures */
	float brightness;       /* SetWindowListBrightness: the colour is multiplied by it (1 = unchanged); software compositor */
	float sys_alpha;        /* SetWindowListSystemAlpha: multiplies the alpha (fades done by the system); 1 by default */
	int syslevel;           /* SetWindowListSystemLevel class, kept */
	int on_screen;
	uint64_t order;         /* higher = in front within its level */
	ws_surface *backing;
	char shm[32];
	int shadow_on, shadow_cr;
	int shadow_for_active;  /* which variant 'shadow' was built for */
	ws_surface *shadow;     /* cached; rebuilt when size or active state changes */
	int shadow_pad, shadow_w, shadow_h;
	ws_event ev[64];
	unsigned ev_head, ev_tail;
	uint32_t owner;
	int sublevel, event_mask;
	uint64_t tags;
	ws_wid parent;          /* SetWindowParent: 0 = none */
	int appearance;         /* bit 0: key appearance, bit 1: main appearance forced on by the client (SetWindowHasKeyAppearance / Main) */
	ws_wid mvparent;        /* movement group: the window this one moves with (0 = none) */
	ws_wid ogparent;        /* ordering group: the window this one is grouped with (0 = none) */
	int ogrel;              /* ordering group: 1 above / -1 below the group parent */
	int corner_radius;
	float resolution;
	ws_surface *content;        /* borrowed */
	ws_surface *front;          /* committed copy of the content: what is shown */
	uint32_t content_id;
	int committed;
	ws_rect dmg; int has_dmg, full_dmg;
	uint32_t shadow_gen;
	int blur_radius, blur_flag; float blur_amount;   /* SetWindowBackgroundBlurRadius */
	ws_rect *shape;       /* window-relative rectangles, NULL = the whole frame */
	int nshape;
	ws_rect *evshape; int nev;   /* SetWindowEventShape: where the window takes events, when different from where it is drawn */
} window;

struct ws_server {
	int w, h;
	window *win;
	size_t n, cap;
	ws_wid next_id;
	uint64_t clock;
	ws_compositor *comp;
	int cx, cy, buttons, cursor_visible;
	ws_wid grab, key_win;
	ws_event_sink sink; void *sink_ctx;
	uint64_t gen;
	ws_surface *cursor_img; int cursor_hx, cursor_hy; uint32_t cursor_serial; int cursor_shape;
	struct track { int used; uint64_t id; ws_wid wid; ws_rect *r; int n; int inside; int disabled; int ox, oy; } trk[64];
	float cursor_scale; ws_surface *cursor_scaled; const ws_surface *cursor_scaled_src; float cursor_scaled_for;       /* SetCursorScale: the pointer is drawn this much larger */
	int decoupled; uint32_t decoupled_by; int rx, ry;           /* AssociateMouseAndMouseCursorPosition(false): the pointer is held still while the mouse keeps sending motion (deltas) */
	ws_rect lock; int locked;                                   /* SetCursorRegionLock: the pointer stays inside this rectangle (the bounds of the locked region) */
	struct kf { uint32_t cid; int ids[8]; int n; } kf[32]; int nkf; int kf_next;      /* key focus list, [0] is the holder */
	struct { uint32_t cid; int count; } hide[64]; int nhide; int obscured;
};

ws_server *ws_server_new(int w, int h)
{
	ws_server *s = calloc(1, sizeof *s);
	if (!s) return NULL;
	s->w = w; s->h = h; s->next_id = 1; s->comp = &ws_compositor_sw; s->cursor_visible = 1; s->cx = w / 2; s->cy = h / 2;
	return s;
}

void ws_server_free(ws_server *s)
{
	if (!s) return;
	ws_surface_free(s->cursor_img);
	for (size_t i = 0; i < s->n; i++) { ws_surface_free(s->win[i].backing); ws_surface_free(s->win[i].shadow); if (s->win[i].shm[0]) ws_shm_unlink(s->win[i].shm); }
	free(s->win); free(s);
}

void ws_server_set_compositor(ws_server *s, ws_compositor *c) { if (s && c) s->comp = c; }

static void bump(ws_server *s) { s->gen++; }
static void kf_remove_at_fwd(ws_server *s, int i);
uint64_t ws_server_generation(const ws_server *s) { return s->gen; }

static window *get(ws_server *s, ws_wid id)
{
	for (size_t i = 0; i < s->n; i++) if (s->win[i].id == id) return &s->win[i];
	return NULL;
}

static ws_wid add_window(ws_server *s, ws_rect f, ws_surface *b, const char *shm);

ws_wid ws_create_window_fd(ws_server *s, ws_rect f, uint32_t owner, int *fd_out)
{
	ws_surface *b = ws_surface_shm_anon(f.w, f.h, fd_out);
	if (!b) return 0;
	ws_wid id = add_window(s, f, b, "");
	if (!id) { ws_surface_free(b); close(*fd_out); return 0; }
	s->win[s->n - 1].owner = owner;
	return id;
}

ws_wid ws_create_window(ws_server *s, ws_rect f)
{
	ws_surface *b = ws_surface_new(f.w, f.h);
	return b ? add_window(s, f, b, "") : 0;
}

ws_wid ws_create_window_shm(ws_server *s, ws_rect f, char name[32])
{
	snprintf(name, 32, "/wsd.%d.%u", (int)getpid(), (unsigned)s->next_id);
	ws_surface *b = ws_surface_shm(name, f.w, f.h, 1);
	if (!b) return 0;
	ws_wid id = add_window(s, f, b, name);
	return id;
}

static ws_wid add_window(ws_server *s, ws_rect f, ws_surface *b, const char *shm)
{
	if (s->n == s->cap) {
		size_t nc = s->cap ? s->cap * 2 : 16;
		window *nw = realloc(s->win, nc * sizeof *nw);
		if (!nw) { ws_surface_free(b); return 0; }
		s->win = nw; s->cap = nc;
	}
	window *w = &s->win[s->n++];
	*w = (window){ .id = s->next_id++, .frame = f, .alpha = 1.0f, .brightness = 1.0f, .sys_alpha = 1.0f, .backing = b, .full_dmg = 1 };
	strncpy(w->shm, shm, sizeof w->shm - 1);
	bump(s);
	return w->id;
}

int ws_release_window(ws_server *s, ws_wid id)
{
	window *w = get(s, id);
	if (!w) return -1;
	if (s->grab == id) s->grab = 0;
	if (s->key_win == id) s->key_win = 0;
	for (size_t i = 0; i < s->n; i++) { if (s->win[i].parent == id) s->win[i].parent = 0; if (s->win[i].mvparent == id) s->win[i].mvparent = 0; if (s->win[i].ogparent == id) s->win[i].ogparent = 0; }       /* children of a destroyed window lose their parent / groups */
	ws_surface_free(w->backing); ws_surface_free(w->shadow); ws_surface_free(w->front); free(w->shape); free(w->evshape); free(w->cap_excl); free(w->mesh);
	bump(s);
	if (w->shm[0]) ws_shm_unlink(w->shm);
	*w = s->win[--s->n];
	return 0;
}

ws_surface *ws_window_backing(ws_server *s, ws_wid id) { window *w = get(s, id); return w ? w->backing : NULL; }

void ws_set_window_shape(ws_server *s, ws_wid id, const ws_rect *r, int n)
{
	window *w = get(s, id);
	if (!w) return;
	free(w->shape); w->shape = NULL; w->nshape = 0;
	if (n > 0 && (w->shape = malloc((size_t)n * sizeof *w->shape))) {
		for (int i = 0; i < n; i++) w->shape[i] = (ws_rect){ r[i].x - w->frame.x, r[i].y - w->frame.y, r[i].w, r[i].h };
		w->nshape = n;
	}
}

uint32_t ws_window_owner(ws_server *s, ws_wid id) { window *w = get(s, id); return w ? w->owner : 0; }
int ws_window_frame(ws_server *s, ws_wid id, ws_rect *out) { window *w = get(s, id); if (!w) return -1; *out = w->frame; return 0; }

int ws_set_window_sublevel(ws_server *s, ws_wid id, int v) { window *w = get(s, id); if (!w) return -1; w->sublevel = (short)v; bump(s); return 0; }
int ws_window_sublevel(ws_server *s, ws_wid id, int *v) { window *w = get(s, id); if (!w) return -1; *v = w->sublevel; return 0; }
int ws_window_shape_bounds(ws_server *s, ws_wid id, ws_rect *out)       /* window-relative bounds of the shape */
{
	window *w = get(s, id);
	if (!w) return -1;
	if (!w->nshape) { *out = (ws_rect){ 0, 0, w->frame.w, w->frame.h }; return 0; }
	int x0 = w->shape[0].x, y0 = w->shape[0].y, x1 = x0 + w->shape[0].w, y1 = y0 + w->shape[0].h;
	for (int i = 1; i < w->nshape; i++) {
		if (w->shape[i].x < x0) x0 = w->shape[i].x;
		if (w->shape[i].y < y0) y0 = w->shape[i].y;
		if (w->shape[i].x + w->shape[i].w > x1) x1 = w->shape[i].x + w->shape[i].w;
		if (w->shape[i].y + w->shape[i].h > y1) y1 = w->shape[i].y + w->shape[i].h;
	}
	*out = (ws_rect){ x0, y0, x1 - x0, y1 - y0 };
	return 0;
}
int ws_window_exists(ws_server *s, ws_wid id) { return get(s, id) != NULL; }
int ws_window_on_screen(ws_server *s, ws_wid id) { window *w = get(s, id); return w && w->on_screen; }
int ws_count_onscreen_owned(ws_server *s, uint32_t owner) { int n = 0; for (size_t i = 0; i < s->n; i++) n += s->win[i].owner == owner && s->win[i].on_screen; return n; }

int ws_window_set_content(ws_server *s, ws_wid id, ws_surface *c, uint32_t buffer_id)
{
	window *w = get(s, id);
	if (!w) return -1;
	ws_surface_free(w->front); w->front = NULL;
	w->content = c; w->content_id = c ? buffer_id : 0; w->committed = 0; w->full_dmg = 1;
	bump(s);
	return 0;
}

/* Copies the flushed rectangle of the bound content into the committed image; what is shown is always that image. */
int ws_window_flush_rect(ws_server *s, ws_wid id, const ws_rect *dirty)
{
	window *w = get(s, id);
	if (!w || !w->content) return -1;
	const ws_surface *c = w->content;
	if (c->px) {                                          /* a CPU-visible buffer; a GPU-only one is read by the GL compositor itself */
		int fresh = !w->front || w->front->w != c->w || w->front->h != c->h;
		if (fresh) { ws_surface_free(w->front); w->front = ws_surface_new(c->w, c->h); if (!w->front) return -1; }
		ws_rect r = (fresh || !dirty) ? (ws_rect){ 0, 0, c->w, c->h } : *dirty;
		int x0 = r.x < 0 ? 0 : r.x, y0 = r.y < 0 ? 0 : r.y, x1 = r.x + r.w > c->w ? c->w : r.x + r.w, y1 = r.y + r.h > c->h ? c->h : r.y + r.h;
		for (int y = y0; y < y1; y++)
			memcpy(w->front->px + (size_t)y * w->front->stride + (size_t)x0 * 4, c->px + (size_t)y * c->stride + (size_t)x0 * 4, (size_t)(x1 > x0 ? x1 - x0 : 0) * 4);
		if (fresh) w->full_dmg = 1;
	}
	if (!w->committed) w->full_dmg = 1;
	w->committed = 1;
	ws_window_damage(s, id, dirty);
	bump(s);
	return 0;
}

int ws_window_commit(ws_server *s, ws_wid id) { return ws_window_flush_rect(s, id, NULL); }

void ws_server_drop_content(ws_server *s, const ws_surface *c)
{
	for (size_t i = 0; i < s->n; i++) if (s->win[i].content == c) {
		ws_surface_free(s->win[i].front); s->win[i].front = NULL;
		s->win[i].content = NULL; s->win[i].content_id = 0; s->win[i].committed = 0; s->win[i].full_dmg = 1;
		bump(s);
	}
}

int ws_window_level(ws_server *s, ws_wid id, int *l) { window *w = get(s, id); if (!w) return -1; *l = w->level; return 0; }
int ws_window_alpha(ws_server *s, ws_wid id, float *a) { window *w = get(s, id); if (!w) return -1; *a = w->alpha; return 0; }
int ws_count_owned(ws_server *s, uint32_t owner) { int n = 0; for (size_t i = 0; i < s->n; i++) n += s->win[i].owner == owner; return n; }

void ws_release_owner(ws_server *s, uint32_t owner)
{
	for (int i = 0; i < 64; i++) if (s->trk[i].used && ws_window_owner(s, s->trk[i].wid) == owner) { free(s->trk[i].r); memset(&s->trk[i], 0, sizeof s->trk[i]); }
	for (int i = 0; i < s->nkf;) { if (s->kf[i].cid == owner) kf_remove_at_fwd(s, i); else i++; }       /* a dying connection loses key focus ... */
	for (int i = 0; i < s->nhide; i++) if (s->hide[i].cid == owner && s->hide[i].count) { s->hide[i].count = 0; s->cursor_serial++; }   /* ... and its cursor hides */
	for (size_t i = 0; i < s->n;) {
		if (s->win[i].owner == owner && owner) ws_release_window(s, s->win[i].id);
		else i++;
	}
}

/* a window that moved takes its movement group (the windows whose mvparent chain leads to it) along by the same offset */
static void move_group(ws_server *s, ws_wid id, int dx, int dy, int depth)
{
	if (depth > 16 || (!dx && !dy)) return;
	for (size_t i = 0; i < s->n; i++) if (s->win[i].mvparent == id) { s->win[i].frame.x += dx; s->win[i].frame.y += dy; move_group(s, s->win[i].id, dx, dy, depth + 1); }
}

/* resource accounting per owner: number of windows and bytes of backing memory (frame area * 4) */
void ws_owner_usage(ws_server *s, uint32_t owner, int *windows, double *bytes)
{
	int n = 0; double b = 0;
	for (size_t i = 0; i < s->n; i++) if (s->win[i].owner == owner) { n++; b += (double)s->win[i].frame.w * (double)s->win[i].frame.h * 4.0; }
	*windows = n; *bytes = b;
}

int ws_move_window(ws_server *s, ws_wid id, int x, int y)
{
	window *w = get(s, id);
	if (!w) return -1;
	int dx = x - (int)w->frame.x, dy = y - (int)w->frame.y;
	w->frame.x = x; w->frame.y = y;
	move_group(s, id, dx, dy, 0);
	bump(s);
	return 0;
}

/* Movement groups (SLSAddWindowToWindowMovementGroup and friends): child follows parent. parent 0 detaches; a cycle is refused. */
int ws_window_set_appearance(ws_server *s, ws_wid id, int bit, int on) { window *w = get(s, id); if (!w) return -1; int old = w->appearance; if (on) w->appearance |= bit; else w->appearance &= ~bit; if (old != w->appearance) { ws_surface_free(w->shadow); w->shadow = NULL; bump(s); } return 0; }
int ws_window_set_movement_parent(ws_server *s, ws_wid child, ws_wid parent)
{
	window *w = get(s, child);
	if (!w || child == parent || (parent && !get(s, parent))) return -1;
	for (ws_wid p = parent; p; ) { if (p == child) return -1; window *pw = get(s, p); p = pw ? pw->mvparent : 0; }
	w->mvparent = parent;
	return 0;
}
ws_wid ws_window_movement_parent(ws_server *s, ws_wid id) { window *w = get(s, id); return w ? w->mvparent : 0; }
void ws_window_clear_movement_group(ws_server *s, ws_wid id)      /* the window leaves its group, and a group it leads dissolves */
{
	window *w = get(s, id); if (!w) return;
	w->mvparent = 0;
	for (size_t i = 0; i < s->n; i++) if (s->win[i].mvparent == id) s->win[i].mvparent = 0;
}
/* members of the group the window belongs to (its root and every descendant), at most max; returns the count */
int ws_window_movement_group(ws_server *s, ws_wid id, ws_wid *out, int max)
{
	window *w = get(s, id); if (!w) return 0;
	ws_wid root = id; for (int d = 0; d < 16 && get(s, root) && get(s, root)->mvparent; d++) root = get(s, root)->mvparent;
	int n = 0; ws_wid queue[256]; int qh = 0, qt = 0;
	int has = 0; for (size_t i = 0; i < s->n; i++) if (s->win[i].mvparent == root) has = 1;
	if (!has) return 0;
	queue[qt++] = root;
	while (qh < qt && qt < 256) {
		ws_wid cur = queue[qh++]; if (n < max) out[n] = cur; n++;
		for (size_t i = 0; i < s->n && qt < 256; i++) if (s->win[i].mvparent == cur) queue[qt++] = s->win[i].id;
	}
	return n;
}
/* Ordering groups: a window ordered with another (above / below) */
int ws_window_set_ordering_parent(ws_server *s, ws_wid child, int rel, ws_wid parent)
{
	window *w = get(s, child);
	if (!w || child == parent || (parent && !get(s, parent))) return -1;
	for (ws_wid p = parent; p; ) { if (p == child) return -1; window *pw = get(s, p); p = pw ? pw->ogparent : 0; }
	w->ogparent = parent; w->ogrel = rel;
	return 0;
}
void ws_window_clear_ordering_group(ws_server *s, ws_wid id)
{
	window *w = get(s, id); if (!w) return;
	w->ogparent = 0;
	for (size_t i = 0; i < s->n; i++) if (s->win[i].ogparent == id) s->win[i].ogparent = 0;
}
int ws_window_ordering_group(ws_server *s, ws_wid id, ws_wid *out, int max)
{
	window *w = get(s, id); if (!w) return 0;
	ws_wid root = id; for (int d = 0; d < 16 && get(s, root) && get(s, root)->ogparent; d++) root = get(s, root)->ogparent;
	int has = 0; for (size_t i = 0; i < s->n; i++) if (s->win[i].ogparent == root) has = 1;
	if (!has) return 0;
	int n = 0; ws_wid queue[256]; int qh = 0, qt = 0; queue[qt++] = root;
	while (qh < qt && qt < 256) {
		ws_wid cur = queue[qh++]; if (n < max) out[n] = cur; n++;
		for (size_t i = 0; i < s->n && qt < 256; i++) if (s->win[i].ogparent == cur) queue[qt++] = s->win[i].id;
	}
	return n;
}

static int key_cmp(const window *x, const window *y)
{
	if (x->level != y->level) return x->level < y->level ? -1 : 1;
	if (x->sublevel != y->sublevel) return x->sublevel < y->sublevel ? -1 : 1;
	return 0;
}

static int by_key(const void *a, const void *b)
{
	const window *x = *(window *const *)a, *y = *(window *const *)b;
	int c = key_cmp(x, y);
	if (c) return c;
	if (x->order != y->order) return x->order < y->order ? -1 : 1;
	return x->id < y->id ? -1 : 1;
}

/* Places w among the on-screen windows and renumbers the order field (1 = rearmost) so that it is strictly increasing.
 * Behaviour verified against the real WindowServer (see test/test_diff.c): without a usable relative window the window goes to the
 * front (WS_ABOVE) or to the back (WS_BELOW) of its own level group; a relative window that is out, unknown, itself or at another level
 * is treated as "no relative window"; the window never adopts the relative window's level. */
static void place(ws_server *s, window *w, int mode, window *rel)
{
	window **v = malloc((s->n + 1) * sizeof *v);
	if (!v) return;
	size_t n = 0;
	for (size_t i = 0; i < s->n; i++) if (s->win[i].on_screen && &s->win[i] != w) v[n++] = &s->win[i];
	qsort(v, n, sizeof *v, by_key);
	size_t at = 0;
	if (rel && rel != w && rel->on_screen && rel->level == w->level) {
		for (size_t i = 0; i < n; i++) if (v[i] == rel) { at = mode == WS_ABOVE ? i + 1 : i; break; }
	} else if (mode == WS_ABOVE) {
		at = 0; for (size_t i = 0; i < n; i++) if (key_cmp(v[i], w) <= 0) at = i + 1;
	} else {
		at = n; for (size_t i = n; i-- > 0;) if (key_cmp(v[i], w) >= 0) at = i;
	}
	bump(s);
	uint64_t k = 1;
	for (size_t i = 0; i < at; i++) v[i]->order = k++;
	w->order = k++; w->on_screen = 1;
	for (size_t i = at; i < n; i++) v[i]->order = k++;
	s->clock = k;
	free(v);
}

static void set_key_window(ws_server *s, ws_wid id);
/* a window that takes the keyboard when it appears: an ordinary application window (not the menu bar, the Dock, an icon or a tooltip) */
static int takes_key(const window *w) { return w->level == 0 && w->frame.w >= 100 && w->frame.h >= 60 && w->alpha * w->sys_alpha > 0; }
static int order_group(ws_server *s, ws_wid id, int mode, ws_wid rel, int depth)
{
	window *w = get(s, id);
	if (!w) return -1;
	if (mode == WS_OUT) {
		w->on_screen = 0; bump(s);
		if (depth == 0 && s->key_win == id) {                              /* the key window went away: the frontmost ordinary window takes the keyboard (as on a Mac), else nobody */
			window *best = NULL;
			for (size_t i = 0; i < s->n; i++) { window *c = &s->win[i]; if (c->on_screen && c->id != id && takes_key(c) && (!best || c->order > best->order)) best = c; }
			set_key_window(s, best ? best->id : 0);
		}
	} else {
		int was_on = w->on_screen;
		place(s, w, mode == WS_BELOW ? WS_BELOW : WS_ABOVE, rel ? get(s, rel) : NULL);
		if (depth == 0 && !was_on && mode != WS_BELOW && takes_key(w)) set_key_window(s, id);      /* a window that appears becomes the key window, the one the keys go to */
	}
	if (depth < 8)                                                      /* the windows grouped with this one for ordering follow it: out with it, else above / below it */
		for (size_t i = 0; i < s->n; i++) {
			window *c = &s->win[i];
			if (c->ogparent != id) continue;
			ws_wid cid = c->id; int crel = c->ogrel;
			order_group(s, cid, mode == WS_OUT ? WS_OUT : (crel < 0 ? WS_BELOW : WS_ABOVE), id, depth + 1);
		}
	return 0;
}
int ws_order_window(ws_server *s, ws_wid id, int mode, ws_wid rel) { return order_group(s, id, mode, rel, 0); }

int ws_window_invalidate_shadow(ws_server *s, ws_wid id) { window *w = get(s, id); if (!w) return -1; ws_surface_free(w->shadow); w->shadow = NULL; bump(s); return 0; }

int ws_window_set_parent(ws_server *s, ws_wid child, ws_wid parent)
{
	window *w = get(s, child);
	if (!w || child == parent || (parent && !get(s, parent))) return -1;
	for (ws_wid p = parent; p; ) { if (p == child) return -1; window *pw = get(s, p); p = pw ? pw->parent : 0; }   /* no cycles */
	w->parent = parent; bump(s);
	return 0;
}
ws_wid ws_window_parent(ws_server *s, ws_wid id) { window *w = get(s, id); return w ? w->parent : 0; }

int ws_set_window_system_alpha(ws_server *s, ws_wid id, float a) { window *w = get(s, id); if (!w) return -1; w->sys_alpha = a < 0 ? 0 : a > 1 ? 1 : a; bump(s); return 0; }
int ws_set_window_filter(ws_server *s, ws_wid id, int type) { window *w = get(s, id); if (!w) return -1; w->filter = type; bump(s); return 0; }

int ws_set_window_transform(ws_server *s, ws_wid id, const float m[6])
{
	window *w = get(s, id); if (!w) return -1;
	for (int i = 0; i < 6; i++) if (!isfinite(m[i]) || fabsf(m[i]) > 1e4f) return -1;
	int ident = m[0] == 1 && m[1] == 0 && m[2] == 0 && m[3] == 1 && m[4] == 0 && m[5] == 0;
	memcpy(w->xf, m, sizeof w->xf); w->has_xf = !ident; bump(s); return 0;
}

/* the window's pixels through its affine transform (inverse mapping, nearest sample) into a new surface covering the transformed box; the box origin goes to *ox,*oy */
/* a window drawn through its mesh: every cell is two triangles whose corners carry the screen position and the position in the window; the pixels are taken from the window with bilinear filtering (premultiplied) */
static float edge_fn(float ax, float ay, float bx, float by, float px, float py) { return (bx - ax) * (py - ay) - (by - ay) * (px - ax); }
static void warp_pixel(const ws_surface *src, float u, float v, uint8_t *out, float cover)
{
	float fu = u * src->w - 0.5f, fv = v * src->h - 0.5f; int iu = (int)floorf(fu), iv = (int)floorf(fv); float a = fu - iu, b = fv - iv;
	float acc[4] = { 0, 0, 0, 0 };
	for (int k = 0; k < 4; k++) {
		int xx = iu + (k & 1), yy = iv + (k >> 1); float wgt = ((k & 1) ? a : 1 - a) * ((k >> 1) ? b : 1 - b);
		if (xx < 0) xx = 0; if (yy < 0) yy = 0; if (xx >= src->w) xx = src->w - 1; if (yy >= src->h) yy = src->h - 1;
		const uint8_t *p = src->px + (size_t)yy * src->stride + (size_t)xx * 4;
		for (int c = 0; c < 4; c++) acc[c] += p[c] * wgt;
	}
	float ia = 1.0f - acc[3] * cover / 255.0f;
	for (int c = 0; c < 4; c++) { float nv = acc[c] * cover + out[c] * ia; out[c] = (uint8_t)(nv > 255 ? 255 : nv + 0.5f); }
}
static ws_surface *warp_surface(const ws_server *srv, const window *w, const ws_surface *src, int *ox, int *oy)
{
	int cols = w->mcols, rows = w->mrows; const float *m = w->mesh;
	/* the mesh of the Dock: source and destination in a coordinate system with y up (the origin is the bottom left corner of the window and of the screen): converted to rows from the top */
	size_t np = (size_t)cols * rows; float *q = malloc(np * 4 * sizeof(float)); if (!q) return NULL;
	for (size_t i = 0; i < np; i++) { q[4 * i] = m[4 * i + 2]; q[4 * i + 1] = (float)srv->h - m[4 * i + 3]; q[4 * i + 2] = m[4 * i] / (float)src->w; q[4 * i + 3] = ((float)src->h - m[4 * i + 1]) / (float)src->h; }
	m = q;
	float minx = 1e9f, miny = 1e9f, maxx = -1e9f, maxy = -1e9f;
	for (int i = 0; i < cols * rows; i++) { float x = m[4 * i], y = m[4 * i + 1]; if (x < minx) minx = x; if (x > maxx) maxx = x; if (y < miny) miny = y; if (y > maxy) maxy = y; }
	int x0 = (int)floorf(minx) - 1, y0 = (int)floorf(miny) - 1, bw = (int)ceilf(maxx) + 1 - x0, bh = (int)ceilf(maxy) + 1 - y0;
	if (bw <= 0 || bh <= 0 || bw > 8192 || bh > 8192) { free(q); return NULL; }
	ws_surface *o = ws_surface_new(bw, bh); if (!o) { free(q); return NULL; }
	/* 2 x 2 samples per pixel kept in a buffer of their own, so that the two triangles of a cell that share a pixel along the diagonal add up to full coverage */
	size_t sw = (size_t)bw * 2, sh = (size_t)bh * 2; uint8_t *ss = calloc(sw * sh, 4); if (!ss) { ws_surface_free(o); free(q); return NULL; }
	for (int r = 0; r + 1 < rows; r++) for (int c = 0; c + 1 < cols; c++) {
		const float *p00 = m + 4 * (r * cols + c), *p10 = p00 + 4, *p01 = p00 + 4 * cols, *p11 = p01 + 4;
		float tx0 = fminf(fminf(p00[0], p10[0]), fminf(p01[0], p11[0])), tx1 = fmaxf(fmaxf(p00[0], p10[0]), fmaxf(p01[0], p11[0]));
		float ty0 = fminf(fminf(p00[1], p10[1]), fminf(p01[1], p11[1])), ty1 = fmaxf(fmaxf(p00[1], p10[1]), fmaxf(p01[1], p11[1]));
		int ix0 = (int)floorf((tx0 - x0) * 2) - 1, ix1 = (int)ceilf((tx1 - x0) * 2) + 1, iy0 = (int)floorf((ty0 - y0) * 2) - 1, iy1 = (int)ceilf((ty1 - y0) * 2) + 1;
		if (ix0 < 0) ix0 = 0; if (iy0 < 0) iy0 = 0; if (ix1 > (int)sw) ix1 = (int)sw; if (iy1 > (int)sh) iy1 = (int)sh;
		/* the quad is mapped bilinearly: p = p00 + s (p10 - p00) + t (p01 - p00) + s t (p00 - p10 - p01 + p11); the inverse is solved per sample (a quadratic in t) */
		float e1x = p10[0] - p00[0], e1y = p10[1] - p00[1], e2x = p01[0] - p00[0], e2y = p01[1] - p00[1], e3x = p00[0] - p10[0] - p01[0] + p11[0], e3y = p00[1] - p10[1] - p01[1] + p11[1];
		for (int y = iy0; y < iy1; y++) for (int x = ix0; x < ix1; x++) {
			float px = x0 + (x + 0.5f) * 0.5f - p00[0], py = y0 + (y + 0.5f) * 0.5f - p00[1];
			float hx = px, hy = py;
			float k2 = e3x * e2y - e3y * e2x, k1 = (e1x * e2y - e1y * e2x) + (hx * e3y - hy * e3x), k0 = hx * e1y - hy * e1x;      /* cross2(g,f), cross2(e,f) + cross2(h,g), cross2(h,e) */
			float t, sv;
			if (fabsf(k2) < 1e-6f) { if (fabsf(k1) < 1e-9f) continue; t = -k0 / k1; sv = (hx - e2x * t) / (e1x + e3x * t); }
			else {
				float disc = k1 * k1 - 4 * k0 * k2; if (disc < 0) continue; float sq = sqrtf(disc);
				float t1 = (-k1 - sq) / (2 * k2), t2 = (-k1 + sq) / (2 * k2), s1 = (hx - e2x * t1) / (e1x + e3x * t1), s2 = (hx - e2x * t2) / (e1x + e3x * t2);
				const float lo = -1e-4f, hi = 1.0001f;
				if (t1 >= lo && t1 <= hi && s1 >= lo && s1 <= hi) { t = t1; sv = s1; } else if (t2 >= lo && t2 <= hi && s2 >= lo && s2 <= hi) { t = t2; sv = s2; } else continue;
			}
			if (t < -1e-4f || t > 1.0001f || sv < -1e-4f || sv > 1.0001f) continue;
			float u = (1 - sv) * (1 - t) * p00[2] + sv * (1 - t) * p10[2] + (1 - sv) * t * p01[2] + sv * t * p11[2];
			float v = (1 - sv) * (1 - t) * p00[3] + sv * (1 - t) * p10[3] + (1 - sv) * t * p01[3] + sv * t * p11[3];
			uint8_t *dst = ss + ((size_t)y * sw + x) * 4; dst[0] = dst[1] = dst[2] = dst[3] = 0;
			warp_pixel(src, u, v, dst, 1.0f);
		}
	}
	for (int y = 0; y < bh; y++) for (int x = 0; x < bw; x++) {
		uint8_t *d = o->px + (size_t)y * o->stride + (size_t)x * 4;
		for (int k = 0; k < 4; k++) { int sum = 0; for (int sy = 0; sy < 2; sy++) for (int sx = 0; sx < 2; sx++) sum += ss[((size_t)(2 * y + sy) * sw + 2 * x + sx) * 4 + k]; d[k] = (uint8_t)((sum + 2) / 4); }
	}
	free(ss);
	free(q);
	*ox = x0; *oy = y0;
	return o;
}
static ws_surface *xform_surface(const window *w, const ws_surface *src, int *ox, int *oy)
{
	float cx = src->w / 2.0f, cy = src->h / 2.0f, a = w->xf[0], b = w->xf[1], c = w->xf[2], d = w->xf[3];
	float det = a * d - b * c; if (fabsf(det) < 1e-6f) return NULL;
	float minx = 1e9f, miny = 1e9f, maxx = -1e9f, maxy = -1e9f;
	for (int i = 0; i < 4; i++) {
		float px = (i & 1 ? src->w : 0) - cx, py = (i & 2 ? src->h : 0) - cy;
		float X = a * px + c * py + cx + w->xf[4], Y = b * px + d * py + cy + w->xf[5];
		if (X < minx) minx = X; if (X > maxx) maxx = X; if (Y < miny) miny = Y; if (Y > maxy) maxy = Y;
	}
	int bw = (int)ceilf(maxx - minx), bh = (int)ceilf(maxy - miny);
	if (bw <= 0 || bh <= 0 || bw > 8192 || bh > 8192) return NULL;
	ws_surface *o = ws_surface_new(bw, bh); if (!o) return NULL;
	for (int y = 0; y < bh; y++) for (int x = 0; x < bw; x++) {
		float X = minx + x + 0.5f - cx - w->xf[4], Y = miny + y + 0.5f - cy - w->xf[5];
		float u = (d * X - c * Y) / det + cx, v = (-b * X + a * Y) / det + cy;
		int iu = (int)floorf(u), iv = (int)floorf(v);
		if (iu < 0 || iv < 0 || iu >= src->w || iv >= src->h) continue;
		memcpy(o->px + (size_t)y * o->stride + (size_t)x * 4, src->px + (size_t)iv * src->stride + (size_t)iu * 4, 4);
	}
	*ox = (int)floorf(minx); *oy = (int)floorf(miny);
	return o;
}

int ws_set_window_system_level(ws_server *s, ws_wid id, int cls) { window *w = get(s, id); if (!w) return -1; w->syslevel = cls; return 0; }

int ws_window_set_event_shape(ws_server *s, ws_wid id, const ws_rect *r, int n)
{
	window *w = get(s, id);
	if (!w) return -1;
	free(w->evshape); w->evshape = NULL; w->nev = 0;
	if (n > 0) { w->evshape = malloc((size_t)n * sizeof *r); if (!w->evshape) return -1; memcpy(w->evshape, r, (size_t)n * sizeof *r); w->nev = n; }
	return 0;
}

int ws_window_has_shadow(ws_server *s, ws_wid id) { window *w = get(s, id); return w && w->shadow_on; }

int ws_set_window_shadow(ws_server *s, ws_wid id, int cr, int on)
{
	window *w = get(s, id);
	if (!w) return -1;
	w->shadow_on = on; w->shadow_cr = cr; bump(s);
	ws_surface_free(w->shadow); w->shadow = NULL;
	return 0;
}

int ws_set_window_level(ws_server *s, ws_wid id, int level)
{
	window *w = get(s, id);
	if (!w) return -1;
	if (w->level != level) { w->level = level; bump(s); if (w->on_screen) place(s, w, WS_ABOVE, NULL); }   /* the real server brings it to the front of the new level */
	return 0;
}
int ws_set_window_warp(ws_server *s, ws_wid id, int cols, int rows, const float *mesh)
{
	window *w = get(s, id); if (!w) return -1;
	free(w->mesh); w->mesh = NULL; w->mcols = w->mrows = 0;
	if (cols >= 2 && rows >= 2 && mesh) {
		size_t n = (size_t)cols * rows * 4; w->mesh = malloc(n * sizeof(float)); if (!w->mesh) return -1;
		memcpy(w->mesh, mesh, n * sizeof(float)); w->mcols = cols; w->mrows = rows;
	}
	bump(s); return 0;
}
int ws_window_warp(ws_server *s, ws_wid id, int *cols, int *rows) { window *w = get(s, id); if (!w) return -1; *cols = w->mcols; *rows = w->mrows; return 0; }
int ws_set_window_capture_exclude(ws_server *s, ws_wid id, const ws_rect *r, int n)
{
	window *w = get(s, id); if (!w) return -1;
	free(w->cap_excl); w->cap_excl = NULL; w->ncap_excl = 0;
	if (n > 0 && r) { w->cap_excl = malloc(sizeof(ws_rect) * (size_t)n); if (!w->cap_excl) return -1; memcpy(w->cap_excl, r, sizeof(ws_rect) * (size_t)n); w->ncap_excl = n; }
	return 0;
}
/* clears what the windows excluded from capture cover in `out`, a capture of the screen rectangle whose top left corner is (ox, oy) */
void ws_capture_apply_exclusions(ws_server *s, ws_surface *out, int ox, int oy)
{
	for (size_t i = 0; i < s->n; i++) {
		window *w = &s->win[i]; if (!w->ncap_excl || !w->on_screen) continue;
		for (int k = 0; k < w->ncap_excl; k++) {
			ws_rect r = w->cap_excl[k]; r.x += w->frame.x - ox; r.y += w->frame.y - oy;
			int x0 = (int)floorf(r.x), y0 = (int)floorf(r.y), x1 = (int)ceilf(r.x + r.w), y1 = (int)ceilf(r.y + r.h);
			if (x0 < 0) x0 = 0; if (y0 < 0) y0 = 0; if (x1 > out->w) x1 = out->w; if (y1 > out->h) y1 = out->h;
			for (int y = y0; y < y1; y++) memset(out->px + (size_t)y * out->stride + x0 * 4, 0, (size_t)(x1 - x0) * 4);
		}
	}
}
int ws_set_window_brightness(ws_server *s, ws_wid id, float b) { window *w = get(s, id); if (!w) return -1; w->brightness = b < 0 ? 0 : b > 8 ? 8 : b; bump(s); return 0; }
int ws_window_brightness(ws_server *s, ws_wid id, float *b) { window *w = get(s, id); if (!w) return -1; *b = w->brightness; return 0; }
int ws_set_window_alpha(ws_server *s, ws_wid id, float a) { window *w = get(s, id); if (!w) return -1; w->alpha = a < 0 ? 0 : a > 1 ? 1 : a; bump(s); return 0; }

static int back_to_front(const void *a, const void *b)
{
	const window *x = *(window *const *)a, *y = *(window *const *)b;
	if (x->level != y->level) return x->level < y->level ? -1 : 1;
	if (x->sublevel != y->sublevel) return x->sublevel < y->sublevel ? -1 : 1;
	if (x->order != y->order) return x->order < y->order ? -1 : 1;
	return x->id < y->id ? -1 : 1;
}

static size_t sorted(ws_server *s, window **out)
{
	size_t n = 0;
	for (size_t i = 0; i < s->n; i++) if (s->win[i].on_screen) out[n++] = &s->win[i];
	qsort(out, n, sizeof *out, back_to_front);
	return n;
}

ws_wid ws_find_window(ws_server *s, int x, int y)
{
	window **v = malloc((s->n + 1) * sizeof *v);
	if (!v) return 0;
	size_t n = sorted(s, v);
	ws_wid hit = 0;
	for (size_t i = n; i-- > 0;) {
		window *w = v[i];
		if (w->alpha * w->sys_alpha <= 0) continue;
		int in = 0;
		if (w->nev) {                                     /* the event shape decides first */
			for (int k = 0; k < w->nev && !in; k++) {
				ws_rect q = w->evshape[k];
				in = x >= w->frame.x + q.x && y >= w->frame.y + q.y && x < w->frame.x + q.x + q.w && y < w->frame.y + q.y + q.h;
			}
		} else if (w->nshape) {                                  /* the window shape (clip) decides, not the bounding frame */
			for (int k = 0; k < w->nshape && !in; k++) {
				ws_rect q = w->shape[k];
				in = x >= w->frame.x + q.x && y >= w->frame.y + q.y && x < w->frame.x + q.x + q.w && y < w->frame.y + q.y + q.h;
			}
		} else {
			in = x >= w->frame.x && y >= w->frame.y && x < w->frame.x + w->frame.w && y < w->frame.y + w->frame.h;
		}
		if (in) { hit = w->id; break; }
	}
	free(v);
	return hit;
}

ws_wid ws_active_window(ws_server *s)
{
	window **v = malloc((s->n + 1) * sizeof *v);
	ws_wid r = 0;
	if (!v) return 0;
	size_t n = sorted(s, v);
	for (size_t i = n; i-- > 0;) if (v[i]->shadow_on && v[i]->alpha > 0) { r = v[i]->id; break; }
	free(v);
	return r;
}

static ws_event_sink sink; static void *sink_ctx;
static uint32_t g_flags;                                   /* modifier state (CGEventFlags) */
static void post_ex(window *w, ws_event e);
static void post(window *w, int type, int x, int y, int buttons, int key)
{
	post_ex(w, (ws_event){ type, w->id, x, y, buttons, key, g_flags, 0, 0, 0 });
}
static void post_ex(window *w, ws_event e)
{
	e.wid = w->id;
	if (w->ev_head - w->ev_tail == 64) w->ev_tail++;           /* queue full: drop the oldest */
	w->ev[w->ev_head++ % 64] = e;
	if (sink) sink(sink_ctx, w->owner, &w->ev[(w->ev_head - 1) % 64]);
}

int ws_window_post(ws_server *s, ws_wid id, const ws_event *e) { window *w = get(s, id); if (!w) return -1; post_ex(w, *e); return 0; }

int ws_next_event(ws_server *s, ws_wid id, ws_event *out)
{
	window *w = get(s, id);
	if (!w || w->ev_head == w->ev_tail) return 0;
	*out = w->ev[w->ev_tail++ % 64];
	return 1;
}

static void set_key_window(ws_server *s, ws_wid id)
{
	if (s->key_win == id) return;
	window *o = get(s, s->key_win), *n = get(s, id);
	if (o) post(o, WS_EV_FOCUS_OUT, 0, 0, 0, 0);
	s->key_win = id;
	if (n) post(n, WS_EV_FOCUS_IN, 0, 0, 0, 0);
}

static void track_update(ws_server *s, int x, int y);

void ws_cursor_lock(ws_server *s, const ws_rect *bounds)
{
	if (bounds && bounds->w > 0 && bounds->h > 0) { s->lock = *bounds; s->locked = 1; } else s->locked = 0;
	if (s->locked) { if (s->cx < s->lock.x) s->cx = s->lock.x; if (s->cy < s->lock.y) s->cy = s->lock.y; if (s->cx >= s->lock.x + s->lock.w) s->cx = s->lock.x + s->lock.w - 1; if (s->cy >= s->lock.y + s->lock.h) s->cy = s->lock.y + s->lock.h - 1; }
}

void ws_server_decouple(ws_server *s, uint32_t owner, int on)
{
	if (on) { s->decoupled = 1; s->decoupled_by = owner; s->rx = s->cx; s->ry = s->cy; }
	else if (s->decoupled && (!owner || s->decoupled_by == owner)) s->decoupled = 0;
}

void ws_server_mouse(ws_server *s, int x, int y, int buttons)
{
	int ddx = 0, ddy = 0, held = 0;
	if (s->decoupled) { ddx = x - s->rx; ddy = y - s->ry; s->rx = x; s->ry = y; x = s->cx; y = s->cy; held = ddx || ddy; }   /* the pointer stays, the motion survives as deltas */
	if (s->locked) { if (x < s->lock.x) x = s->lock.x; if (y < s->lock.y) y = s->lock.y; if (x >= s->lock.x + s->lock.w) x = s->lock.x + s->lock.w - 1; if (y >= s->lock.y + s->lock.h) y = s->lock.y + s->lock.h - 1; }
	x = x < 0 ? 0 : x >= s->w ? s->w - 1 : x;
	y = y < 0 ? 0 : y >= s->h ? s->h - 1 : y;
	int moved = x != s->cx || y != s->cy, pressed = buttons & ~s->buttons, released = s->buttons & ~buttons;
	s->cx = x; s->cy = y;
	if (moved) track_update(s, x, y);
	if (moved && s->obscured) { s->obscured = 0; s->cursor_serial++; }       /* an obscured cursor comes back when the mouse moves */
	ws_wid target = s->grab ? s->grab : ws_find_window(s, x, y);
	if (pressed && !s->grab && target) {                       /* click: raise within its level, focus, grab */
		ws_order_window(s, target, WS_ABOVE, 0);
		set_key_window(s, target);
		s->grab = target;
	} else if (pressed && !target) {
		set_key_window(s, 0);
	}
	window *w = get(s, target);
	if (w) {
		int lx = x - w->frame.x, ly = y - w->frame.y;
		if (moved) post(w, WS_EV_MOUSE_MOVE, lx, ly, buttons, 0);
		else if (held) post_ex(w, (ws_event){ WS_EV_MOUSE_MOVE, w->id, lx, ly, buttons, 0, 0, ddx, ddy, 0 });
		if (pressed) post(w, WS_EV_MOUSE_DOWN, lx, ly, buttons, 0);
		if (released) post(w, WS_EV_MOUSE_UP, lx, ly, buttons, 0);
	}
	if (released && !buttons) s->grab = 0;
	s->buttons = buttons;
}

static ws_key_filter key_filter; static void *key_filter_ctx;
void ws_server_set_key_filter(ws_server *s, ws_key_filter fn, void *ctx) { (void)s; key_filter = fn; key_filter_ctx = ctx; }
void ws_server_key(ws_server *s, int key, int down)
{
	if (key_filter && key_filter(key_filter_ctx, key, down)) return;
	ws_server_key_unfiltered(s, key, down);
}

void ws_server_key_unfiltered(ws_server *s, int key, int down)
{
	window *w = get(s, s->key_win);
	if (w) post(w, down ? WS_EV_KEY_DOWN : WS_EV_KEY_UP, 0, 0, s->buttons, key);
}

void ws_server_set_event_sink(ws_server *s, ws_event_sink fn, void *ctx) { (void)s; sink = fn; sink_ctx = ctx; }
int ws_server_buttons(ws_server *s) { return s->buttons; }
void ws_server_warp_cursor(ws_server *s, int x, int y) { if (s->locked) { if (x < s->lock.x) x = s->lock.x; if (y < s->lock.y) y = s->lock.y; if (x >= s->lock.x + s->lock.w) x = s->lock.x + s->lock.w - 1; if (y >= s->lock.y + s->lock.h) y = s->lock.y + s->lock.h - 1; }  s->cx = x < 0 ? 0 : x >= s->w ? s->w - 1 : x; s->cy = y < 0 ? 0 : y >= s->h ? s->h - 1 : y; }
int ws_set_window_event_mask(ws_server *s, ws_wid id, int m) { window *w = get(s, id); if (!w) return -1; w->event_mask = m; return 0; }
int ws_window_event_mask(ws_server *s, ws_wid id, int *m) { window *w = get(s, id); if (!w) return -1; *m = w->event_mask; return 0; }

void ws_cursor_pos(ws_server *s, int *x, int *y) { *x = s->cx; *y = s->cy; }
ws_wid ws_key_window(ws_server *s) { return s->key_win; }
void ws_cursor_show(ws_server *s, int v) { if ((v != 0) != s->cursor_visible) s->cursor_serial++; s->cursor_visible = v != 0; }

/* ---- cursor: an image with a hotspot, independent of every window buffer ---- */
static int in_poly(const float *px, const float *py, int n, float x, float y)
{
	int c = 0;
	for (int i = 0, j = n - 1; i < n; j = i++)
		if (((py[i] > y) != (py[j] > y)) && (x < (px[j] - px[i]) * (y - py[i]) / (py[j] - py[i]) + px[i])) c = !c;
	return c;
}

#define CURSOR_SIZE 24
/* the default arrow: black with a white outline, 4x4 supersampled, premultiplied BGRA, hotspot at the tip */
static ws_surface *make_default_cursor(void)
{
	static const float ax[] = { 0, 0, 4, 7, 9, 6.2f, 11 }, ay[] = { 0, 16, 12.5f, 18.5f, 17.5f, 11.5f, 11.5f };
	float ox[7], oy[7];
	for (int i = 0; i < 7; i++) { ox[i] = (ax[i] - 4.5f) * 1.18f + 4.5f; oy[i] = (ay[i] - 9.0f) * 1.18f + 9.0f; }
	ws_surface *img = ws_surface_new(CURSOR_SIZE, CURSOR_SIZE);
	if (!img) return NULL;
	for (int y = 0; y < CURSOR_SIZE; y++)
		for (int x = 0; x < CURSOR_SIZE; x++) {
			int fill = 0, outline = 0;
			for (int sy = 0; sy < 4; sy++)
				for (int sx = 0; sx < 4; sx++) {
					float fx = x - 2 + (sx + 0.5f) / 4, fy = y - 2 + (sy + 0.5f) / 4;     /* the polygon is offset by 2 so the outline fits */
					if (in_poly(ax, ay, 7, fx, fy)) fill++;
					else if (in_poly(ox, oy, 7, fx, fy)) outline++;
				}
			float fo = fill / 16.0f, ou = outline / 16.0f;
			uint8_t *d = img->px + (size_t)y * img->stride + (size_t)x * 4;
			uint8_t a = (uint8_t)((fo + ou) * 255.0f + 0.5f), white = (uint8_t)(ou * 255.0f + 0.5f);   /* premultiplied: black fill, white outline */
			d[0] = d[1] = d[2] = white; d[3] = a;
		}
	return img;
}

static int default_hot_x(void) { return 2; }                       /* the arrow's tip is at (0,0) of the polygon, drawn 2 px into the image */

const ws_surface *ws_cursor_image(ws_server *s, int *hx, int *hy)
{
	if (!s->cursor_img) {
		s->cursor_img = make_default_cursor();
		s->cursor_hx = s->cursor_hy = default_hot_x();
		s->cursor_serial++;
	}
	if (hx) *hx = s->cursor_hx;
	if (hy) *hy = s->cursor_hy;
	return s->cursor_img;
}

uint32_t ws_cursor_serial(const ws_server *s) { return s->cursor_serial; }
static int hidden_total(const ws_server *s) { int t = 0; for (int i = 0; i < s->nhide; i++) t += s->hide[i].count; return t; }
int ws_cursor_visible(const ws_server *s) { return s->cursor_visible && !s->obscured && hidden_total(s) == 0; }

void ws_server_set_cursor_shape(ws_server *s, int shape)
{
	if (shape == s->cursor_shape && s->cursor_img) return;
	int hx = 0, hy = 0; ws_surface *img = ws_cursor_shape_image(shape, &hx, &hy);
	ws_server_set_cursor_image(s, img, hx, hy);                      /* NULL: the default arrow */
	ws_surface_free(img);
	s->cursor_shape = img ? shape : 0;
}

void ws_server_set_cursor_image(ws_server *s, const ws_surface *img, int hx, int hy)
{
	ws_surface_free(s->cursor_img); s->cursor_img = NULL;
	if (img && img->px) {
		s->cursor_img = ws_surface_new(img->w, img->h);
		if (s->cursor_img) {
			for (int y = 0; y < img->h; y++) memcpy(s->cursor_img->px + (size_t)y * s->cursor_img->stride, img->px + (size_t)y * img->stride, (size_t)img->w * 4);
			s->cursor_hx = hx; s->cursor_hy = hy;
		}
	}
	s->cursor_serial++;                                              /* a NULL image falls back to the default arrow on the next query */
}

/* software path: blend the cursor image onto a finished frame */
/* bilinear scaling of premultiplied BGRA */
static ws_surface *scale_surface(const ws_surface *src, float k)
{
	int nw = (int)(src->w * k + 0.5f), nh = (int)(src->h * k + 0.5f);
	if (nw < 1 || nh < 1 || nw > 512 || nh > 512) return NULL;
	ws_surface *d = ws_surface_new(nw, nh); if (!d) return NULL;
	for (int y = 0; y < nh; y++) {
		float fy = (y + 0.5f) / k - 0.5f; int y0 = (int)floorf(fy); float ty = fy - y0; int y1 = y0 + 1; if (y0 < 0) y0 = 0; if (y1 < 0) y1 = 0; if (y0 >= src->h) y0 = src->h - 1; if (y1 >= src->h) y1 = src->h - 1;
		for (int x = 0; x < nw; x++) {
			float fx = (x + 0.5f) / k - 0.5f; int x0 = (int)floorf(fx); float tx = fx - x0; int x1 = x0 + 1; if (x0 < 0) x0 = 0; if (x1 < 0) x1 = 0; if (x0 >= src->w) x0 = src->w - 1; if (x1 >= src->w) x1 = src->w - 1;
			const uint8_t *p00 = src->px + (size_t)y0 * src->stride + 4 * (size_t)x0, *p10 = src->px + (size_t)y0 * src->stride + 4 * (size_t)x1;
			const uint8_t *p01 = src->px + (size_t)y1 * src->stride + 4 * (size_t)x0, *p11 = src->px + (size_t)y1 * src->stride + 4 * (size_t)x1;
			uint8_t *o = d->px + (size_t)y * d->stride + 4 * (size_t)x;
			for (int c = 0; c < 4; c++) { float v = (p00[c] * (1 - tx) + p10[c] * tx) * (1 - ty) + (p01[c] * (1 - tx) + p11[c] * tx) * ty; o[c] = (uint8_t)(v + 0.5f); }
		}
	}
	return d;
}

void ws_set_cursor_scale(ws_server *s, float k) { if (k > 0 && k < 16 && k != s->cursor_scale) { s->cursor_scale = k; s->cursor_serial++; } }

static void draw_cursor(ws_server *s, ws_surface *scr)
{
	int hx, hy;
	const ws_surface *img = ws_cursor_image(s, &hx, &hy);
	if (!img) return;
	float k = s->cursor_scale > 0 ? s->cursor_scale : 1.0f;
	if (k != 1.0f) {
		if (!s->cursor_scaled || s->cursor_scaled_src != img || s->cursor_scaled_for != k) { ws_surface_free(s->cursor_scaled); s->cursor_scaled = scale_surface(img, k); s->cursor_scaled_src = img; s->cursor_scaled_for = k; }
		if (s->cursor_scaled) { img = s->cursor_scaled; hx = (int)(hx * k + 0.5f); hy = (int)(hy * k + 0.5f); }
	}
	ws_rect all = { 0, 0, scr->w, scr->h };
	s->comp->over(s->comp, scr, s->cx - hx, s->cy - hy, img, 1.0f, all);
}

static void ensure_shadow(ws_server *s, window *w, int active)
{
	(void)s;
	ws_shadow_params p = ws_shadow_defaults(active);
	if (!w->shadow || w->shadow_for_active != active || w->shadow_w != w->frame.w || w->shadow_h != w->frame.h) {
		ws_surface_free(w->shadow);
		w->shadow = ws_shadow_make(w->frame.w, w->frame.h, w->shadow_cr, &p, &w->shadow_pad);
		w->shadow_gen++;
		w->shadow_for_active = active; w->shadow_w = w->frame.w; w->shadow_h = w->frame.h;
	}
}

static void draw_shadow(ws_server *s, window *w, ws_surface *screen, int active)
{
	ensure_shadow(s, w, active);
	if (!w->shadow) return;
	ws_rect all = { 0, 0, screen->w, screen->h };
	s->comp->over(s->comp, screen, w->frame.x - w->shadow_pad, w->frame.y - w->shadow_pad, w->shadow, w->alpha * w->sys_alpha, all);
}

void ws_window_damage(ws_server *s, ws_wid id, const ws_rect *r)
{
	window *w = get(s, id);
	if (!w) return;
	bump(s);
	if (!r) { w->full_dmg = 1; return; }
	int x0 = r->x < 0 ? 0 : r->x, y0 = r->y < 0 ? 0 : r->y;                  /* clip to the window */
	int x1 = r->x + r->w > w->frame.w ? w->frame.w : r->x + r->w, y1 = r->y + r->h > w->frame.h ? w->frame.h : r->y + r->h;
	if (x1 <= x0 || y1 <= y0) return;
	if (!w->has_dmg) { w->dmg = (ws_rect){ x0, y0, x1 - x0, y1 - y0 }; w->has_dmg = 1; return; }
	int ax1 = w->dmg.x + w->dmg.w, ay1 = w->dmg.y + w->dmg.h;
	if (x0 < w->dmg.x) w->dmg.x = x0;
	if (y0 < w->dmg.y) w->dmg.y = y0;
	w->dmg.w = (x1 > ax1 ? x1 : ax1) - w->dmg.x; w->dmg.h = (y1 > ay1 ? y1 : ay1) - w->dmg.y;
}

void ws_server_clear_damage(ws_server *s) { for (size_t i = 0; i < s->n; i++) { s->win[i].has_dmg = 0; s->win[i].full_dmg = 0; } }
void ws_server_desktop_color(ws_server *s, float rgb[3]) { (void)s; rgb[0] = rgb[1] = rgb[2] = 37.0f / 255.0f; }
void ws_draw_cursor(ws_server *s, ws_surface *screen) { if (ws_cursor_visible(s)) draw_cursor(s, screen); }

void ws_server_walk(ws_server *s, ws_visit_fn fn, void *ctx)
{
	window **v = malloc((s->n + 1) * sizeof *v);
	if (!v) return;
	ws_wid act = ws_active_window(s);
	size_t n = sorted(s, v);
	for (size_t i = 0; i < n; i++) {
		window *w = v[i];
		if (w->shadow_on) ensure_shadow(s, w, w->id == act || w->appearance);
		ws_visit vis;
		memset(&vis, 0, sizeof vis);
		vis.id = w->id; vis.frame = w->frame; vis.alpha = w->alpha * w->sys_alpha; vis.corner_radius = w->corner_radius ? w->corner_radius : (w->shadow_on ? w->shadow_cr : 0); vis.blur_radius = w->blur_radius; vis.active = w->id == act || w->appearance;
		vis.pixels = (w->content && w->committed) ? (w->front ? w->front : w->content) : w->backing;
		vis.buffer_id = (w->content && w->committed) ? w->content_id : 0;
		if (w->shadow_on && w->shadow) {
			vis.shadow = w->shadow; vis.shadow_x = w->frame.x - w->shadow_pad; vis.shadow_y = w->frame.y - w->shadow_pad; vis.shadow_gen = w->shadow_gen;
		}
		vis.invert = w->filter == 2; vis.has_xf = w->has_xf; memcpy(vis.xf, w->xf, sizeof vis.xf);
		vis.damage = w->dmg; vis.has_damage = w->has_dmg; vis.full_damage = w->full_dmg;
		fn(ctx, &vis);
	}
	free(v);
}

/* a copy of the window's pixels with the four corners cut to a circle of radius r (anti-aliased by exact-ish coverage); NULL when nothing to cut */
static ws_surface *round_corners(const ws_surface *src, int r)
{
	if (r <= 0 || !src || !src->px || src->w < 2 * r || src->h < 2 * r) return NULL;
	ws_surface *o = ws_surface_new(src->w, src->h); if (!o) return NULL;
	for (int y = 0; y < src->h; y++) memcpy(o->px + (size_t)y * o->stride, src->px + (size_t)y * src->stride, (size_t)src->w * 4);
	for (int cy = 0; cy < r; cy++)
		for (int cx = 0; cx < r; cx++) {
			float dx = (float)r - (cx + 0.5f), dy = (float)r - (cy + 0.5f);
			float d = sqrtf(dx * dx + dy * dy) - (float)r;                      /* signed distance to the arc, > 0 outside */
			float cov = 0.5f - d; cov = cov < 0 ? 0 : cov > 1 ? 1 : cov;
			if (cov >= 1.0f) continue;
			int xs[2] = { cx, src->w - 1 - cx }, ys[2] = { cy, src->h - 1 - cy };
			for (int a = 0; a < 2; a++) for (int b = 0; b < 2; b++) {
				uint8_t *p = o->px + (size_t)ys[b] * o->stride + (size_t)xs[a] * 4;
				for (int k = 0; k < 4; k++) p[k] = (uint8_t)(p[k] * cov + 0.5f);
			}
		}
	return o;
}

static void apply_zoom(ws_surface *screen);
void ws_compose_scene(ws_server *s, ws_surface *screen)
{
	window **v = malloc((s->n + 1) * sizeof *v);
	if (!v) return;
	ws_rect all = { 0, 0, screen->w, screen->h };
	ws_wid act = ws_active_window(s);
	s->comp->fill(s->comp, screen, all, 37.0f / 255.0f, 37.0f / 255.0f, 37.0f / 255.0f, 1.0f);   /* desktop: #252525 */
	size_t n = sorted(s, v);
	for (size_t i = 0; i < n; i++) {
		if (v[i]->blur_radius > 0) {                                          /* blur what is behind the window (sigma = radius / 2: an estimate) */
			if (s->comp->flush) s->comp->flush(s->comp);
			float sg = ws_blur_sigma(v[i]->blur_radius); int m = (int)ceilf(3.0f * sg);
			ws_blur_region(screen, (ws_rect){ v[i]->frame.x - m, v[i]->frame.y - m, v[i]->frame.w + 2 * m, v[i]->frame.h + 2 * m }, v[i]->frame, sg);   /* the backdrop beyond the edges feeds the blur */
		}
		{
			const ws_surface *px = (v[i]->content && v[i]->committed) ? (v[i]->front ? v[i]->front : v[i]->content) : v[i]->backing;
			ws_surface *xs = NULL; int xo = 0, yo = 0;
			ws_surface *inv = NULL;
			if (v[i]->filter == 2 && px && px->px && (inv = ws_surface_new(px->w, px->h))) {      /* CIColorInvert on premultiplied pixels: c' = a - c */
				for (int y = 0; y < px->h; y++) { const uint8_t *sp = px->px + (size_t)y * px->stride; uint8_t *dp = inv->px + (size_t)y * inv->stride; for (int x = 0; x < px->w; x++, sp += 4, dp += 4) { dp[0] = sp[3] - sp[0]; dp[1] = sp[3] - sp[1]; dp[2] = sp[3] - sp[2]; dp[3] = sp[3]; } }
				px = inv;
			}
			ws_surface *brt = NULL;
			if (v[i]->brightness != 1.0f && px && px->px && (brt = ws_surface_new(px->w, px->h))) {          /* SetWindowListBrightness: the colour channels of the premultiplied pixels are scaled, the alpha is not */
				int k = (int)(v[i]->brightness * 256.0f + 0.5f);
				for (int y = 0; y < px->h; y++) { const uint8_t *sp = px->px + (size_t)y * px->stride; uint8_t *dp = brt->px + (size_t)y * brt->stride; for (int x = 0; x < px->w; x++, sp += 4, dp += 4) { for (int c = 0; c < 3; c++) { int t = (sp[c] * k + 128) >> 8; dp[c] = (uint8_t)(t > sp[3] ? sp[3] : t); } dp[3] = sp[3]; } }
				px = brt;
			}
			ws_surface *rnd = NULL; int cr = v[i]->corner_radius ? v[i]->corner_radius : (v[i]->shadow_on ? v[i]->shadow_cr : 0);
			if (cr > 0 && px && (rnd = round_corners(px, cr))) px = rnd;
			if (v[i]->mesh && px && px->px) { xs = warp_surface(s, v[i], px, &xo, &yo); xo -= (int)v[i]->frame.x; yo -= (int)v[i]->frame.y; }
			else if (v[i]->has_xf && px && px->px) xs = xform_surface(v[i], px, &xo, &yo);
			if (xs) { s->comp->over(s->comp, screen, v[i]->frame.x + xo, v[i]->frame.y + yo, xs, v[i]->alpha * v[i]->sys_alpha, all); if (s->comp->flush) s->comp->flush(s->comp); ws_surface_free(xs); }
			else s->comp->over(s->comp, screen, v[i]->frame.x, v[i]->frame.y, px, v[i]->alpha * v[i]->sys_alpha, all);
			if (inv || rnd || brt) { if (s->comp->flush) s->comp->flush(s->comp); ws_surface_free(inv); ws_surface_free(rnd); ws_surface_free(brt); }
		}
		/* the shadow layer is rendered above its window (it is cut out of the window shape; the inner rim lies inside it) */
		if (v[i]->shadow_on) draw_shadow(s, v[i], screen, v[i]->id == act || v[i]->appearance);
	}
	if (s->comp->flush) s->comp->flush(s->comp);
	free(v);
	apply_zoom(screen);
}

/* screen zoom (SetZoomParameters): the frame is magnified about the zoom centre, nearest sample; scale 1 is off */
static float zoom_scale_v = 1.0f; static int zoom_cx, zoom_cy;
int ws_server_set_zoom(ws_server *s, float scale, int cx, int cy) { (void)s; if (!(scale >= 1.0f) || scale > 64.0f) scale = 1.0f; zoom_scale_v = scale; zoom_cx = cx; zoom_cy = cy; return 0; }
static void apply_zoom(ws_surface *screen)
{
	if (zoom_scale_v <= 1.0f || screen->w <= 0 || screen->h <= 0) return;
	float vw = screen->w / zoom_scale_v, vh = screen->h / zoom_scale_v;
	float x0 = zoom_cx - vw / 2, y0 = zoom_cy - vh / 2;                       /* the visible window, kept on the screen */
	if (x0 < 0) x0 = 0; if (y0 < 0) y0 = 0; if (x0 + vw > screen->w) x0 = screen->w - vw; if (y0 + vh > screen->h) y0 = screen->h - vh;
	ws_surface *copy = ws_surface_new(screen->w, screen->h); if (!copy) return;
	for (int y = 0; y < screen->h; y++) memcpy(copy->px + (size_t)y * copy->stride, screen->px + (size_t)y * screen->stride, (size_t)screen->w * 4);
	for (int y = 0; y < screen->h; y++) {
		int sy = (int)(y0 + (y + 0.5f) / zoom_scale_v); if (sy >= screen->h) sy = screen->h - 1;
		for (int x = 0; x < screen->w; x++) { int sx = (int)(x0 + (x + 0.5f) / zoom_scale_v); if (sx >= screen->w) sx = screen->w - 1; memcpy(screen->px + (size_t)y * screen->stride + (size_t)x * 4, copy->px + (size_t)sy * copy->stride + (size_t)sx * 4, 4); }
	}
	ws_surface_free(copy);
}

void ws_compose(ws_server *s, ws_surface *screen)
{
	ws_compose_scene(s, screen);
	if (ws_cursor_visible(s)) draw_cursor(s, screen);
}

/* ---- key focus ---- */
static struct kf *kf_find(ws_server *s, uint32_t cid) { for (int i = 0; i < s->nkf; i++) if (s->kf[i].cid == cid) return &s->kf[i]; return NULL; }
static void kf_remove_at(ws_server *s, int i) { memmove(&s->kf[i], &s->kf[i + 1], (size_t)(s->nkf - i - 1) * sizeof s->kf[0]); s->nkf--; }

int ws_keyfocus_steal(ws_server *s, uint32_t cid, int options, int want_id, int *id_out)
{
	if (id_out) *id_out = 0;
	if (!cid) return -600;
	if (!want_id && s->nkf && s->kf[0].cid == cid) return (options >> 9) & 1 ? 1010 : 0;       /* already the holder */
	if (!s->nkf) {                                                                              /* nobody stole it: the key window's owner has it */
		ws_wid kw = s->key_win;
		if (kw && ws_window_owner(s, kw) == cid) return 1010;
	}
	struct kf e = { cid, { 0 }, 0 };
	struct kf *old = kf_find(s, cid);
	if (old) { e = *old; kf_remove_at(s, (int)(old - s->kf)); }
	else if (s->nkf == 32) return 1010;
	int id = 0;
	if (want_id) { id = s->kf_next ? (s->kf_next == 0x7fffffff ? WS_KEYFOCUS_FIRST_ID : s->kf_next + 1) : WS_KEYFOCUS_FIRST_ID; s->kf_next = id; }
	int have = 0;
	for (int i = 0; i < e.n; i++) have |= e.ids[i] == id && !want_id;
	if (!have && e.n < 8) memmove(&e.ids[1], &e.ids[0], (size_t)e.n++ * sizeof e.ids[0]), e.ids[0] = id;
	memmove(&s->kf[1], &s->kf[0], (size_t)s->nkf * sizeof s->kf[0]);                            /* the thief becomes the holder */
	s->kf[0] = e; s->nkf++;
	if (id_out) *id_out = id;
	bump(s);
	return 0;
}

int ws_keyfocus_release(ws_server *s, uint32_t cid, int id)
{
	for (int i = 0; i < s->nkf; i++) {
		struct kf *e = &s->kf[i];
		if (id ? 1 : e->cid == cid)
			for (int k = 0; k < e->n; k++) if (e->ids[k] == id) {
				memmove(&e->ids[k], &e->ids[k + 1], (size_t)(e->n - k - 1) * sizeof e->ids[0]);
				if (--e->n == 0) kf_remove_at(s, i);
				bump(s);
				return 0;
			}
	}
	return 0;
}

uint32_t ws_keyfocus_holder(ws_server *s, int *is_default)
{
	if (s->nkf) { if (is_default) *is_default = 0; return s->kf[0].cid; }
	if (is_default) *is_default = 1;
	return s->key_win ? ws_window_owner(s, s->key_win) : 0;
}

/* ---- cursor hide / obscure ---- */
static int *hide_slot(ws_server *s, uint32_t cid, int create)
{
	for (int i = 0; i < s->nhide; i++) if (s->hide[i].cid == cid) return &s->hide[i].count;
	if (!create || s->nhide == 64) return NULL;
	s->hide[s->nhide].cid = cid; s->hide[s->nhide].count = 0;
	return &s->hide[s->nhide++].count;
}
static void cursor_changed(ws_server *s) { s->cursor_serial++; }
void ws_cursor_hide(ws_server *s, uint32_t cid) { int *c = hide_slot(s, cid, 1); if (c) { (*c)++; cursor_changed(s); } }
void ws_cursor_unhide(ws_server *s, uint32_t cid, int force)
{
	int *c = hide_slot(s, cid, 0);
	if (c) { if (force) *c = 0; else if (*c > 0) (*c)--; }
	cursor_changed(s);
}
void ws_cursor_obscure(ws_server *s, uint32_t cid) { (void)cid; if (!s->obscured) { s->obscured = 1; cursor_changed(s); } }
void ws_cursor_reveal(ws_server *s, uint32_t cid) { (void)cid; if (s->obscured) { s->obscured = 0; cursor_changed(s); } }

static void kf_remove_at_fwd(ws_server *s, int i) { kf_remove_at(s, i); bump(s); }

/* ---- backdrop blur ---- */
int ws_set_window_blur(ws_server *s, ws_wid id, int radius, int flag, float amount)
{
	window *w = get(s, id);
	if (!w) return -1;
	radius = radius < 0 ? 0 : radius > 60 ? 60 : radius;
	if (radius != w->blur_radius || flag != w->blur_flag || amount != w->blur_amount) { w->blur_radius = radius; w->blur_flag = flag; w->blur_amount = amount; bump(s); }
	return 0;
}
int ws_window_blur(ws_server *s, ws_wid id, int *radius, int *flag, float *amount)
{
	window *w = get(s, id);
	if (!w) return -1;
	*radius = w->blur_radius; *flag = w->blur_flag; *amount = w->blur_amount;
	return 0;
}
int ws_server_has_blur(ws_server *s) { for (size_t i = 0; i < s->n; i++) if (s->win[i].on_screen && s->win[i].blur_radius > 0) return 1; return 0; }

int ws_resize_window(ws_server *s, ws_wid id, int w, int h)
{
	window *win = get(s, id);
	if (!win || w <= 0 || h <= 0 || w > 16384 || h > 16384) return -1;
	if (win->frame.w != w || win->frame.h != h) {
		win->frame.w = w; win->frame.h = h;
		if (win->shadow) { ws_surface_free(win->shadow); win->shadow = NULL; }          /* the shadow is rebuilt for the new size */
		win->full_dmg = 1; win->has_dmg = 1;
		bump(s);
	}
	return 0;
}

void ws_server_scroll(ws_server *s, int x, int y, int dx, int dy, int continuous)
{
	ws_wid target = s->grab ? s->grab : ws_find_window(s, x, y);
	window *w = get(s, target);
	if (!w) return;
	post_ex(w, (ws_event){ WS_EV_SCROLL, w->id, x - w->frame.x, y - w->frame.y, s->buttons, 0, g_flags, dx, dy, continuous });
}

void ws_server_flags(ws_server *s, uint32_t flags)
{
	if (flags == g_flags) return;
	g_flags = flags;
	window *w = get(s, s->key_win);
	if (w) post_ex(w, (ws_event){ WS_EV_FLAGS, w->id, 0, 0, s->buttons, 0, flags, 0, 0, 0 });
}
uint32_t ws_server_modifier_flags(const ws_server *s) { (void)s; return g_flags; }

int ws_list_windows(ws_server *s, uint32_t owner, int onscreen, ws_wid *out, int max)
{
	window **v = malloc((s->n + 1) * sizeof *v);
	if (!v) return 0;
	size_t n = sorted(s, v);
	int total = 0;
	for (size_t i = n; i-- > 0;) if (!owner || v[i]->owner == owner) { if (total < max) out[total] = v[i]->id; total++; }
	if (!onscreen) for (size_t i = 0; i < s->n; i++) if (!s->win[i].on_screen && (!owner || s->win[i].owner == owner)) { if (total < max) out[total] = s->win[i].id; total++; }
	free(v);
	return total;
}

uint64_t ws_window_tags(ws_server *s, ws_wid id) { window *w = get(s, id); return w ? w->tags : 0; }
int ws_window_set_tags(ws_server *s, ws_wid id, uint64_t tags, int clear)
{
	window *w = get(s, id);
	if (!w) return -1;
	uint64_t n = clear ? (w->tags & ~tags) : (w->tags | tags);
	if (n != w->tags) { w->tags = n; bump(s); }
	return 0;
}

int ws_set_window_corner_radius(ws_server *s, ws_wid id, int radius)
{
	window *w = get(s, id);
	if (!w) return -1;
	radius = radius < 0 ? 0 : radius;
	if (radius != w->corner_radius) { w->corner_radius = radius; bump(s); }
	return 0;
}

/* ---- tracking regions ---- */
static int track_contains(const struct track *t, int lx, int ly)
{
	for (int i = 0; i < t->n; i++) if (lx >= t->r[i].x && ly >= t->r[i].y && lx < t->r[i].x + t->r[i].w && ly < t->r[i].y + t->r[i].h) return 1;
	return 0;
}
static void track_update(ws_server *s, int x, int y)
{
	ws_wid top = ws_find_window(s, x, y);
	for (int i = 0; i < 64; i++) {
		struct track *t = &s->trk[i];
		if (!t->used) continue;
		window *w = get(s, t->wid);
		int in = !t->disabled && w && top == t->wid && track_contains(t, x - w->frame.x, y - w->frame.y);
		if (in == t->inside) continue;
		t->inside = in;
		if (w) post_ex(w, (ws_event){ in ? WS_EV_TRACK_ENTER : WS_EV_TRACK_EXIT, w->id, x - w->frame.x, y - w->frame.y, s->buttons, (int)(uint32_t)t->id, g_flags, 0, (int)(uint32_t)(t->id >> 32), 0 });
	}
}
int ws_tracking_set(ws_server *s, uint64_t id, ws_wid wid, const ws_rect *rects, int n)
{
	struct track *t = NULL;
	for (int i = 0; i < 64; i++) if (s->trk[i].used && s->trk[i].id == id) t = &s->trk[i];
	for (int i = 0; i < 64 && !t; i++) if (!s->trk[i].used) t = &s->trk[i];
	if (!t || !get(s, wid)) return -1;
	if (t->used == 0) { int mine = 0; uint32_t ow = get(s, wid)->owner; for (int i = 0; i < 64; i++) if (s->trk[i].used && ws_window_owner(s, s->trk[i].wid) == ow) mine++; if (mine >= 24) return -1; }      /* a connection cannot fill the table of tracking regions */
	free(t->r); t->r = NULL; t->n = 0;
	if (n > 0) { t->r = malloc((size_t)n * sizeof *t->r); if (!t->r) return -1; memcpy(t->r, rects, (size_t)n * sizeof *t->r); t->n = n; }
	t->used = 1; t->id = id; t->wid = wid; t->inside = 0; t->ox = t->oy = 0;
	track_update(s, s->cx, s->cy);                                 /* a region created under the pointer is entered at once */
	return 0;
}
void ws_tracking_remove(ws_server *s, uint64_t id)
{
	for (int i = 0; i < 64; i++) if (s->trk[i].used && s->trk[i].id == id) { free(s->trk[i].r); memset(&s->trk[i], 0, sizeof s->trk[i]); }
}
void ws_tracking_remove_window(ws_server *s, ws_wid wid)
{
	for (int i = 0; i < 64; i++) if (s->trk[i].used && s->trk[i].wid == wid) { free(s->trk[i].r); memset(&s->trk[i], 0, sizeof s->trk[i]); }
}
int ws_tracking_set_enabled(ws_server *s, uint64_t id, ws_wid wid, int enabled)
{
	for (int i = 0; i < 64; i++) if (s->trk[i].used && s->trk[i].id == id && s->trk[i].wid == wid) { s->trk[i].disabled = !enabled; track_update(s, s->cx, s->cy); return 0; }
	return -1;
}
int ws_tracking_move(ws_server *s, uint64_t id, ws_wid wid, int x, int y)      /* the region's origin moves to (x, y) in window coordinates; -1 when the window has no such region */
{
	for (int i = 0; i < 64; i++) if (s->trk[i].used && s->trk[i].id == id && s->trk[i].wid == wid) {
		struct track *t = &s->trk[i];
		for (int k = 0; k < t->n; k++) { t->r[k].x += x - t->ox; t->r[k].y += y - t->oy; }
		t->ox = x; t->oy = y; track_update(s, s->cx, s->cy);
		return 0;
	}
	return -1;
}
int ws_tracking_set_shape(ws_server *s, uint64_t id, const ws_rect *rects, int n)
{
	for (int i = 0; i < 64; i++) if (s->trk[i].used && s->trk[i].id == id) return ws_tracking_set(s, id, s->trk[i].wid, rects, n);
	return -1;
}

int ws_set_window_resolution(ws_server *s, ws_wid id, float scale) { window *w = get(s, id); if (!w) return -1; if (w->resolution != scale) { w->resolution = scale; bump(s); } return 0; }
int ws_window_resolution(ws_server *s, ws_wid id, float *scale) { window *w = get(s, id); if (!w) return -1; *scale = w->resolution > 0 ? w->resolution : 1.0f; return 0; }
int ws_set_window_frame(ws_server *s, ws_wid id, int x, int y, int w, int h)
{
	window *win = get(s, id);
	if (!win) return -1;
	if (win->frame.x != x || win->frame.y != y) { int dx = x - (int)win->frame.x, dy = y - (int)win->frame.y; win->frame.x = x; win->frame.y = y; move_group(s, id, dx, dy, 0); bump(s); }
	return ws_resize_window(s, id, w, h);
}
