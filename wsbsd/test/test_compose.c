#include "ws.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); fails++; } } while (0)

static const uint8_t *at(const ws_surface *s, int x, int y) { return s->px + (size_t)y * s->stride + (size_t)x * 4; }

typedef struct { ws_wid ids[8]; int n; ws_visit v[8]; } walk_log;
static void on_visit(void *ctx, const ws_visit *v) { walk_log *l = ctx; if (l->n < 8) { l->ids[l->n] = v->id; l->v[l->n] = *v; l->n++; } }

/* the renderer interface used by the GL compositor: z-order walk and damage tracking */
static void test_walk(void)
{
	ws_server *srv = ws_server_new(400, 300);
	ws_wid a = ws_create_window(srv, (ws_rect){ 10, 10, 100, 80 }), b = ws_create_window(srv, (ws_rect){ 50, 40, 100, 80 }), c = ws_create_window(srv, (ws_rect){ 90, 70, 60, 60 });
	ws_set_window_shadow(srv, b, 12, 1); ws_set_window_alpha(srv, b, 0.5f);
	ws_order_window(srv, c, WS_ABOVE, 0); ws_order_window(srv, a, WS_ABOVE, 0); ws_order_window(srv, b, WS_ABOVE, 0);     /* back to front: c, a, b */
	walk_log l; memset(&l, 0, sizeof l);
	ws_server_walk(srv, on_visit, &l);
	CHECK(l.n == 3 && l.ids[0] == c && l.ids[1] == a && l.ids[2] == b);
	CHECK(l.v[2].alpha == 0.5f && l.v[2].corner_radius == 12 && l.v[2].active && !l.v[1].active && l.v[1].corner_radius == 0);
	CHECK(l.v[2].shadow != NULL && l.v[2].shadow_gen > 0 && l.v[1].shadow == NULL && l.v[2].shadow_x < 50 && l.v[2].shadow_y < 40);
	CHECK(l.v[0].pixels != NULL && l.v[0].buffer_id == 0 && l.v[0].frame.w == 60);
	CHECK(l.v[0].full_damage && l.v[1].full_damage && l.v[2].full_damage);                  /* new windows need a full upload */
	uint32_t gen = l.v[2].shadow_gen;
	ws_server_clear_damage(srv);
	ws_window_damage(srv, a, &(ws_rect){ 10, 10, 20, 20 });
	ws_window_damage(srv, a, &(ws_rect){ 25, 5, 20, 10 });                                     /* union, clipped to the window */
	ws_window_damage(srv, a, &(ws_rect){ 95, 70, 50, 50 });
	ws_window_damage(srv, c, &(ws_rect){ 500, 500, 5, 5 });                                    /* entirely outside: ignored */
	memset(&l, 0, sizeof l);
	ws_server_walk(srv, on_visit, &l);
	CHECK(l.v[1].id == a && l.v[1].has_damage && !l.v[1].full_damage && l.v[1].damage.x == 10 && l.v[1].damage.y == 5 && l.v[1].damage.w == 90 && l.v[1].damage.h == 75);
	CHECK(!l.v[0].has_damage && !l.v[2].has_damage && l.v[2].shadow_gen == gen);              /* nothing changed: the shadow is not rebuilt */
	ws_window_damage(srv, b, NULL);
	ws_move_window(srv, b, 60, 50);                                                            /* moving does not need a new shadow */
	memset(&l, 0, sizeof l); ws_server_walk(srv, on_visit, &l);
	CHECK(l.v[2].full_damage && l.v[2].shadow_gen == gen);
	/* bound content replaces the backing store only after a commit, and unbinding returns to it */
	ws_surface *content = ws_surface_new(100, 80);
	ws_window_set_content(srv, a, content, 7);
	ws_server_clear_damage(srv); memset(&l, 0, sizeof l); ws_server_walk(srv, on_visit, &l);
	CHECK(l.v[1].pixels != content && l.v[1].buffer_id == 0);
	ws_window_commit(srv, a);
	memset(&l, 0, sizeof l); ws_server_walk(srv, on_visit, &l);
	CHECK(l.v[1].pixels != content && l.v[1].pixels != NULL && l.v[1].buffer_id == 7 && l.v[1].full_damage);   /* a committed copy, not the client buffer */
	CHECK(memcmp(l.v[1].pixels->px, content->px, 4) == 0 && l.v[1].pixels->w == 100);
	/* a client write is invisible until it is flushed; a rect flush copies and damages only that rectangle */
	content->px[0] = 0x55;
	ws_server_clear_damage(srv); memset(&l, 0, sizeof l); ws_server_walk(srv, on_visit, &l);
	CHECK(l.v[1].pixels->px[0] != 0x55 && !l.v[1].has_damage);
	uint64_t g0 = ws_server_generation(srv);
	ws_window_flush_rect(srv, a, &(ws_rect){ 0, 0, 10, 10 });
	memset(&l, 0, sizeof l); ws_server_walk(srv, on_visit, &l);
	CHECK(l.v[1].pixels->px[0] == 0x55 && l.v[1].has_damage && !l.v[1].full_damage && l.v[1].damage.w == 10 && ws_server_generation(srv) != g0);
	/* the cursor is independent of every window: moving it changes no scene generation, a new image bumps the serial */
	{
		uint64_t g1 = ws_server_generation(srv); uint32_t s1 = ws_cursor_serial(srv); int hx, hy;
		ws_server_warp_cursor(srv, 50, 60);
		CHECK(ws_server_generation(srv) == g1 && ws_cursor_image(srv, &hx, &hy) != NULL && hx == 2 && hy == 2);
		ws_surface *ci = ws_surface_new(8, 8);
		ws_server_set_cursor_image(srv, ci, 3, 4);
		const ws_surface *got = ws_cursor_image(srv, &hx, &hy);
		CHECK(got != NULL && got->w == 8 && hx == 3 && hy == 4 && ws_cursor_serial(srv) != s1 && ws_server_generation(srv) == g1);
		ws_surface_free(ci);
	}
	ws_server_drop_content(srv, content);
	memset(&l, 0, sizeof l); ws_server_walk(srv, on_visit, &l);
	CHECK(l.v[1].pixels != content && l.v[1].buffer_id == 0);
	ws_surface_free(content);
	ws_server_free(srv);
}

int main(void)
{
	ws_server *srv = ws_server_new(320, 200);
	ws_surface *scr = ws_surface_new(320, 200);
	ws_rect r1 = { 20, 20, 160, 100 }, r2 = { 100, 60, 160, 100 }, r3 = { 150, 10, 80, 80 };
	ws_wid a = ws_create_window(srv, r1), b = ws_create_window(srv, r2), c = ws_create_window(srv, r3);
	CHECK(a && b && c);
	ws_rect fa = { 0, 0, 160, 100 }, fb = { 0, 0, 160, 100 }, fc = { 0, 0, 80, 80 };
	ws_fill(ws_window_backing(srv, a), fa, 1, 0, 0, 1);       /* opaque red   */
	ws_fill(ws_window_backing(srv, b), fb, 0, 0, 1, 1);       /* opaque blue  */
	ws_fill(ws_window_backing(srv, c), fc, 0, 1, 0, 1);       /* opaque green */
	ws_order_window(srv, a, WS_ABOVE, 0);
	ws_order_window(srv, b, WS_ABOVE, 0);
	ws_order_window(srv, c, WS_ABOVE, 0);

	/* z-order: c over b over a */
	CHECK(ws_find_window(srv, 120, 70) == b);
	CHECK(ws_find_window(srv, 160, 40) == c);
	CHECK(ws_find_window(srv, 30, 30) == a);
	CHECK(ws_find_window(srv, 5, 5) == 0);

	/* raise a above everything */
	ws_order_window(srv, a, WS_ABOVE, 0);
	CHECK(ws_find_window(srv, 120, 70) == a);
	/* put a directly below b */
	ws_order_window(srv, a, WS_BELOW, b);
	CHECK(ws_find_window(srv, 120, 70) == b);

	/* levels beat order */
	ws_set_window_level(srv, a, 10);
	ws_order_window(srv, a, WS_ABOVE, 0);
	CHECK(ws_find_window(srv, 120, 70) == a);
	ws_set_window_level(srv, a, 0);

	/* half-transparent green over the opaque stack */
	ws_order_window(srv, c, WS_ABOVE, 0);
	ws_set_window_alpha(srv, c, 0.5f);
	ws_compose(srv, scr);
	const uint8_t *p = at(scr, 160, 40);            /* c over b/desktop region */
	CHECK(p[1] > 100 && p[1] < 160);               /* green channel is about half */
	CHECK(p[3] == 255);                            /* destination stays opaque */
	CHECK(at(scr, 2, 2)[0] == 41);                 /* desktop blue = 0.16*255 */

	/* move and out */
	ws_move_window(srv, b, 200, 150);
	CHECK(ws_find_window(srv, 120, 70) != b);
	ws_order_window(srv, c, WS_OUT, 0);
	CHECK(ws_find_window(srv, 160, 40) != c);

	/* input: click raises and focuses, grab keeps drag events on the pressed window, keys go to focus */
	ws_order_window(srv, c, WS_ABOVE, 0);
	ws_set_window_level(srv, a, 0); ws_set_window_level(srv, b, 0);
	ws_order_window(srv, a, WS_ABOVE, 0); ws_order_window(srv, b, WS_ABOVE, 0);
	ws_move_window(srv, b, 200, 120);
	ws_event ev;
	ws_server_mouse(srv, 30, 30, 0);                        /* over a (b is elsewhere) */
	CHECK(ws_next_event(srv, a, &ev) && ev.type == WS_EV_MOUSE_MOVE && ev.x == 10 && ev.y == 10);
	ws_server_mouse(srv, 30, 30, 1);                        /* press on a */
	CHECK(ws_key_window(srv) == a);
	int got_down = 0, got_focus = 0;
	while (ws_next_event(srv, a, &ev)) { if (ev.type == WS_EV_MOUSE_DOWN) got_down = 1; if (ev.type == WS_EV_FOCUS_IN) got_focus = 1; }
	CHECK(got_down && got_focus);
	ws_server_mouse(srv, 250, 140, 1);                      /* drag out over b: still goes to a */
	CHECK(ws_next_event(srv, a, &ev) && ev.type == WS_EV_MOUSE_MOVE && ev.x == 230);
	CHECK(!ws_next_event(srv, b, &ev));
	ws_server_mouse(srv, 250, 140, 0);                      /* release */
	ws_server_key(srv, 42, 1);
	CHECK(ws_next_event(srv, a, &ev) && ev.type == WS_EV_MOUSE_UP);
	CHECK(ws_next_event(srv, a, &ev) && ev.type == WS_EV_KEY_DOWN && ev.key == 42);
	ws_server_mouse(srv, 250, 140, 1); ws_server_mouse(srv, 250, 140, 0);   /* click on b: raise + focus */
	CHECK(ws_key_window(srv) == b && ws_find_window(srv, 250, 140) == b);
	ws_server_mouse(srv, 5, 190, 1); ws_server_mouse(srv, 5, 190, 0);        /* click on empty desktop: focus cleared */
	CHECK(ws_key_window(srv) == 0);
	ws_server_mouse(srv, 700, 700, 0);
	{ int cx, cy; ws_cursor_pos(srv, &cx, &cy); CHECK(cx == 319 && cy == 199); }   /* clamped to the screen */

	ws_compose(srv, scr);
	CHECK(ws_write_ppm(scr, "out.ppm") == 0);
	ws_surface_free(scr);
	ws_server_free(srv);
	test_walk();
	printf(fails ? "%d failures\n" : "all tests passed\n", fails);
	return fails != 0;
}
