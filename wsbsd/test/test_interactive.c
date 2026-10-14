/* Interactivity: a click posted with PostEventRecord reaches the window, the client redraws only the toggle and flushes only that
 * rectangle, and the compositor shows exactly that change (nothing the client wrote but did not flush). Then a slider drag does the same
 * with one small flush per move. Screenshots are taken without the cursor and compared pixel by pixel. */
#include "ws_client.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int failures;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

enum { WX = 100, WY = 100, W = 400, H = 200 };
static const ws_rect TOGGLE = { 40, 40, 60, 32 }, TRACK = { 40, 120, 300, 8 }, CORNER = { 340, 10, 40, 40 };

static void fill(ws_surface *s, ws_rect r, uint8_t R, uint8_t G, uint8_t B)
{
	for (int y = r.y; y < r.y + r.h; y++)
		for (int x = r.x; x < r.x + r.w; x++) { uint8_t *p = s->px + (size_t)y * s->stride + (size_t)x * 4; p[0] = B; p[1] = G; p[2] = R; p[3] = 255; }
}

static void draw_toggle(ws_surface *s, int on)
{
	if (on) fill(s, TOGGLE, 51, 199, 89); else fill(s, TOGGLE, 150, 150, 150);
	fill(s, (ws_rect){ TOGGLE.x + (on ? 34 : 4), TOGGLE.y + 4, 22, 24 }, 255, 255, 255);   /* knob */
}

static void draw_fill(ws_surface *s, int x0, int x1)       /* slider fill from the track start to local x */
{
	fill(s, (ws_rect){ TRACK.x + x0, TRACK.y, x1 - x0, TRACK.h }, 0, 122, 255);
}

typedef struct { int w, h; uint8_t *rgb; } img;

static int load(const char *path, img *o)
{
	FILE *f = fopen(path, "rb"); int mx;
	if (!f || fscanf(f, "P6 %d %d %d", &o->w, &o->h, &mx) != 3 || fgetc(f) < 0) { if (f) fclose(f); return -1; }
	o->rgb = malloc((size_t)o->w * o->h * 3);
	int ok = o->rgb && fread(o->rgb, 3, (size_t)o->w * o->h, f) == (size_t)o->w * o->h;
	fclose(f);
	return ok ? 0 : -1;
}

/* bounding box (screen coordinates) of the pixels that differ; w == 0 when identical */
static ws_rect diff_bbox(const img *a, const img *b)
{
	int x0 = a->w, y0 = a->h, x1 = -1, y1 = -1;
	for (int y = 0; y < a->h; y++)
		for (int x = 0; x < a->w; x++)
			if (memcmp(a->rgb + ((size_t)y * a->w + x) * 3, b->rgb + ((size_t)y * a->w + x) * 3, 3)) {
				if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
			}
	return x1 < 0 ? (ws_rect){ 0, 0, 0, 0 } : (ws_rect){ x0, y0, x1 - x0 + 1, y1 - y0 + 1 };
}

static int inside(ws_rect r, ws_rect outer)       /* r (screen) within outer (window-local rect) */
{
	outer.x += WX; outer.y += WY;
	return r.w > 0 && r.x >= outer.x && r.y >= outer.y && r.x + r.w <= outer.x + outer.w && r.y + r.h <= outer.y + outer.h;
}

static void px(const img *i, int x, int y, int *r, int *g, int *b) { const uint8_t *p = i->rgb + ((size_t)y * i->w + x) * 3; *r = p[0]; *g = p[1]; *b = p[2]; }

static int shot(ws_conn *c, const char *path, img *o)
{
	if (ws_screenshot_scene(c, path)) return -1;
	return load(path, o);
}

/* wait for an event of the given type on the event channel (focus events etc. are skipped) */
static int wait_event(ws_conn *c, int type, ws_event *e)
{
	for (int i = 0; i < 20; i++) { if (!ws_conn_next_pushed_event(c, 500, e)) return 0; if (e->type == type) return 1; }
	return 0;
}

int main(int argc, char **argv)
{
	const char *prefix = argc > 1 ? argv[1] : "interactive";
	char pa[256], pb[256], pc[256], pd[256], pe[256];
	snprintf(pa, sizeof pa, "%s-A.ppm", prefix); snprintf(pb, sizeof pb, "%s-B.ppm", prefix); snprintf(pc, sizeof pc, "%s-C.ppm", prefix);
	snprintf(pd, sizeof pd, "%s-D.ppm", prefix); snprintf(pe, sizeof pe, "%s-E.ppm", prefix);
	ws_conn *c = ws_connect(NULL);
	if (!c) { fprintf(stderr, "test_interactive: cannot connect to wsd\n"); return 1; }
	ws_win w; ws_cbuf cb; uint32_t sid;
	if (ws_win_create(c, (ws_rect){ WX, WY, W, H }, 0, &w) || ws_cbuf_create(c, W, H, &cb) || ws_surface_add(c, &w, &sid) ||
	    ws_surface_bind_buffer(c, &w, sid, &cb)) { fprintf(stderr, "test_interactive: setup failed\n"); return 1; }
	ws_win_set_event_mask(c, &w, -1);
	ws_win_order(c, &w, WS_ABOVE, 0);
	ws_surface *s = cb.buf.cpu;
	fill(s, (ws_rect){ 0, 0, W, H }, 240, 240, 245);
	fill(s, TRACK, 210, 210, 215);
	draw_toggle(s, 0);
	CHECK(ws_surface_flush(c, &w, sid, NULL) == 0);
	img A, B, C, D, E;
	CHECK(shot(c, pa, &A) == 0);
	int r, g, b;
	px(&A, WX + TOGGLE.x + 45, WY + TOGGLE.y + 16, &r, &g, &b);
	CHECK(r == 150 && g == 150 && b == 150);                                   /* toggle off: grey */

	/* the client writes something it does not flush, then clicks the toggle */
	fill(s, CORNER, 255, 0, 0);
	CHECK(ws_post_mouse_event(c, 5, WX + 50, WY + 50, 0, 0, 0) == 0);          /* move onto the toggle */
	CHECK(ws_post_mouse_event(c, 1, WX + 50, WY + 50, 0, 1, 0) == 0);          /* left down */
	ws_event e;
	CHECK(wait_event(c, WS_EV_MOUSE_DOWN, &e) && e.wid == w.id);
	CHECK(e.x == 50 && e.y == 50);                                             /* window-local coordinates */
	int hit = e.x >= TOGGLE.x && e.x < TOGGLE.x + TOGGLE.w && e.y >= TOGGLE.y && e.y < TOGGLE.y + TOGGLE.h;
	CHECK(hit);
	if (hit) {
		draw_toggle(s, 1);
		CHECK(ws_surface_flush(c, &w, sid, &TOGGLE) == 0);                     /* only the toggle */
	}
	CHECK(ws_post_mouse_event(c, 2, WX + 50, WY + 50, 0, 1, 0) == 0);
	CHECK(wait_event(c, WS_EV_MOUSE_UP, &e));
	CHECK(shot(c, pb, &B) == 0);
	ws_rect d = diff_bbox(&A, &B);
	CHECK(inside(d, TOGGLE));                                                  /* the compositor updated the frame, only there */
	px(&B, WX + TOGGLE.x + 10, WY + TOGGLE.y + 16, &r, &g, &b);
	CHECK(r == 51 && g == 199 && b == 89);                                     /* toggle on: green */
	px(&B, WX + CORNER.x + 5, WY + CORNER.y + 5, &r, &g, &b);
	CHECK(r == 240 && g == 240 && b == 245);                                   /* the unflushed red square is not shown */

	/* flushing the other rectangle shows it, and nothing else */
	CHECK(ws_surface_flush(c, &w, sid, &CORNER) == 0);
	CHECK(shot(c, pc, &C) == 0);
	d = diff_bbox(&B, &C);
	CHECK(inside(d, CORNER));
	px(&C, WX + CORNER.x + 5, WY + CORNER.y + 5, &r, &g, &b);
	CHECK(r == 255 && g == 0 && b == 0);

	/* slider drag: button down on the track start, dragged moves, one small flush per move */
	int cur = 0;
	CHECK(ws_post_mouse_event(c, 1, WX + TRACK.x, WY + TRACK.y + 4, 0, 1, 0) == 0);
	CHECK(wait_event(c, WS_EV_MOUSE_DOWN, &e));
	int moves = 0, flushes = 0;
	for (int x = 30; x <= 210; x += 30) {
		CHECK(ws_post_mouse_event(c, 6, WX + TRACK.x + x, WY + TRACK.y + 4, 0, 0, 0) == 0);   /* left mouse dragged */
		if (!wait_event(c, WS_EV_MOUSE_MOVE, &e)) break;
		moves++;
		int lx = e.x - TRACK.x;
		if (lx > cur && (e.buttons & 1)) {
			draw_fill(s, cur, lx);
			if (ws_surface_flush(c, &w, sid, &(ws_rect){ TRACK.x + cur, TRACK.y, lx - cur, TRACK.h }) == 0) flushes++;
			cur = lx;
		}
	}
	CHECK(ws_post_mouse_event(c, 2, WX + TRACK.x + 210, WY + TRACK.y + 4, 0, 1, 0) == 0);
	CHECK(moves == 7 && flushes == 7 && cur == 210);
	CHECK(shot(c, pd, &D) == 0);
	d = diff_bbox(&C, &D);
	CHECK(inside(d, TRACK) && d.w == 210);                                     /* exactly the dragged span, nothing outside the track */
	px(&D, WX + TRACK.x + 100, WY + TRACK.y + 4, &r, &g, &b);
	CHECK(r == 0 && g == 122 && b == 255);
	px(&D, WX + TRACK.x + 250, WY + TRACK.y + 4, &r, &g, &b);
	CHECK(r == 210 && g == 210 && b == 215);                                   /* beyond the thumb: still the empty track */

	/* idle: nothing written, nothing flushed -> an identical frame */
	CHECK(shot(c, pe, &E) == 0);
	CHECK(diff_bbox(&D, &E).w == 0);
	ws_server_quit(c);
	printf(failures ? "%d failures\n" : "interactive: all checks passed\n", failures);
	return failures != 0;
}
