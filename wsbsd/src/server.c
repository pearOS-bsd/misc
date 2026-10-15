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
	ws_surface *content;        /* borrowed */
	ws_surface *front;          /* committed copy of the content: what is shown */
	uint32_t content_id;
	int committed;
	ws_rect dmg; int has_dmg, full_dmg;
	uint32_t shadow_gen;
	int blur_radius, blur_flag; float blur_amount;   /* SetWindowBackgroundBlurRadius */
	ws_rect *shape;       /* window-relative rectangles, NULL = the whole frame */
	int nshape;
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
	ws_surface *cursor_img; int cursor_hx, cursor_hy; uint32_t cursor_serial;
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
	*w = (window){ .id = s->next_id++, .frame = f, .alpha = 1.0f, .backing = b, .full_dmg = 1 };
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
	ws_surface_free(w->backing); ws_surface_free(w->shadow); ws_surface_free(w->front); free(w->shape);
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
	for (int i = 0; i < s->nkf;) { if (s->kf[i].cid == owner) kf_remove_at_fwd(s, i); else i++; }       /* a dying connection loses key focus ... */
	for (int i = 0; i < s->nhide; i++) if (s->hide[i].cid == owner && s->hide[i].count) { s->hide[i].count = 0; s->cursor_serial++; }   /* ... and its cursor hides */
	for (size_t i = 0; i < s->n;) {
		if (s->win[i].owner == owner && owner) ws_release_window(s, s->win[i].id);
		else i++;
	}
}

int ws_move_window(ws_server *s, ws_wid id, int x, int y)
{
	window *w = get(s, id);
	if (!w) return -1;
	w->frame.x = x; w->frame.y = y;
	bump(s);
	return 0;
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

int ws_order_window(ws_server *s, ws_wid id, int mode, ws_wid rel)
{
	window *w = get(s, id);
	if (!w) return -1;
	if (mode == WS_OUT) { w->on_screen = 0; bump(s); return 0; }
	place(s, w, mode == WS_BELOW ? WS_BELOW : WS_ABOVE, rel ? get(s, rel) : NULL);
	return 0;
}

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
		if (w->alpha <= 0) continue;
		int in = 0;
		if (w->nshape) {                                  /* the window shape (clip) decides, not the bounding frame */
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

void ws_server_mouse(ws_server *s, int x, int y, int buttons)
{
	x = x < 0 ? 0 : x >= s->w ? s->w - 1 : x;
	y = y < 0 ? 0 : y >= s->h ? s->h - 1 : y;
	int moved = x != s->cx || y != s->cy, pressed = buttons & ~s->buttons, released = s->buttons & ~buttons;
	s->cx = x; s->cy = y;
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
		if (pressed) post(w, WS_EV_MOUSE_DOWN, lx, ly, buttons, 0);
		if (released) post(w, WS_EV_MOUSE_UP, lx, ly, buttons, 0);
	}
	if (released && !buttons) s->grab = 0;
	s->buttons = buttons;
}

void ws_server_key(ws_server *s, int key, int down)
{
	window *w = get(s, s->key_win);
	if (w) post(w, down ? WS_EV_KEY_DOWN : WS_EV_KEY_UP, 0, 0, s->buttons, key);
}

void ws_server_set_event_sink(ws_server *s, ws_event_sink fn, void *ctx) { (void)s; sink = fn; sink_ctx = ctx; }
int ws_server_buttons(ws_server *s) { return s->buttons; }
void ws_server_warp_cursor(ws_server *s, int x, int y) { s->cx = x < 0 ? 0 : x >= s->w ? s->w - 1 : x; s->cy = y < 0 ? 0 : y >= s->h ? s->h - 1 : y; }
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
static void draw_cursor(ws_server *s, ws_surface *scr)
{
	int hx, hy;
	const ws_surface *img = ws_cursor_image(s, &hx, &hy);
	if (!img) return;
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
	s->comp->over(s->comp, screen, w->frame.x - w->shadow_pad, w->frame.y - w->shadow_pad, w->shadow, w->alpha, all);
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
void ws_server_desktop_color(ws_server *s, float rgb[3]) { (void)s; rgb[0] = 0.10f; rgb[1] = 0.12f; rgb[2] = 0.16f; }
void ws_draw_cursor(ws_server *s, ws_surface *screen) { if (ws_cursor_visible(s)) draw_cursor(s, screen); }

void ws_server_walk(ws_server *s, ws_visit_fn fn, void *ctx)
{
	window **v = malloc((s->n + 1) * sizeof *v);
	if (!v) return;
	ws_wid act = ws_active_window(s);
	size_t n = sorted(s, v);
	for (size_t i = 0; i < n; i++) {
		window *w = v[i];
		if (w->shadow_on) ensure_shadow(s, w, w->id == act);
		ws_visit vis;
		memset(&vis, 0, sizeof vis);
		vis.id = w->id; vis.frame = w->frame; vis.alpha = w->alpha; vis.corner_radius = w->shadow_on ? w->shadow_cr : 0; vis.blur_radius = w->blur_radius; vis.active = w->id == act;
		vis.pixels = (w->content && w->committed) ? (w->front ? w->front : w->content) : w->backing;
		vis.buffer_id = (w->content && w->committed) ? w->content_id : 0;
		if (w->shadow_on && w->shadow) {
			vis.shadow = w->shadow; vis.shadow_x = w->frame.x - w->shadow_pad; vis.shadow_y = w->frame.y - w->shadow_pad; vis.shadow_gen = w->shadow_gen;
		}
		vis.damage = w->dmg; vis.has_damage = w->has_dmg; vis.full_damage = w->full_dmg;
		fn(ctx, &vis);
	}
	free(v);
}

void ws_compose_scene(ws_server *s, ws_surface *screen)
{
	window **v = malloc((s->n + 1) * sizeof *v);
	if (!v) return;
	ws_rect all = { 0, 0, screen->w, screen->h };
	ws_wid act = ws_active_window(s);
	s->comp->fill(s->comp, screen, all, 0.10f, 0.12f, 0.16f, 1.0f);   /* desktop */
	size_t n = sorted(s, v);
	for (size_t i = 0; i < n; i++) {
		if (v[i]->blur_radius > 0) {                                          /* blur what is behind the window (sigma = radius / 2: an estimate) */
			if (s->comp->flush) s->comp->flush(s->comp);
			float sg = ws_blur_sigma(v[i]->blur_radius); int m = (int)ceilf(3.0f * sg);
			ws_blur_region(screen, (ws_rect){ v[i]->frame.x - m, v[i]->frame.y - m, v[i]->frame.w + 2 * m, v[i]->frame.h + 2 * m }, v[i]->frame, sg);   /* the backdrop beyond the edges feeds the blur */
		}
		s->comp->over(s->comp, screen, v[i]->frame.x, v[i]->frame.y, (v[i]->content && v[i]->committed) ? (v[i]->front ? v[i]->front : v[i]->content) : v[i]->backing, v[i]->alpha, all);
		/* the shadow layer is rendered above its window (it is cut out of the window shape; the inner rim lies inside it) */
		if (v[i]->shadow_on) draw_shadow(s, v[i], screen, v[i]->id == act);
	}
	if (s->comp->flush) s->comp->flush(s->comp);
	free(v);
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
