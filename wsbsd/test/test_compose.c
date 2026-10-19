#include <math.h>
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
	/* key focus: theft ids count up from 0x65, release by id hands focus back, a dying connection loses it */
	{
		int id1 = 0, id2 = 0, dflt = 9;
		CHECK(ws_keyfocus_steal(srv, 5, 0, 1, &id1) == 0 && id1 == 0x65);
		CHECK(ws_keyfocus_steal(srv, 6, 0, 1, &id2) == 0 && id2 == 0x66);
		CHECK(ws_keyfocus_holder(srv, &dflt) == 6 && dflt == 0);
		CHECK(ws_keyfocus_release(srv, 6, id2) == 0 && ws_keyfocus_holder(srv, &dflt) == 5);        /* back to the previous holder */
		CHECK(ws_keyfocus_steal(srv, 5, 0x200, 0, NULL) == 1010 && ws_keyfocus_steal(srv, 5, 0, 0, NULL) == 0);
		CHECK(ws_keyfocus_steal(srv, 0, 0, 0, NULL) == -600);
		ws_release_owner(srv, 5);
		CHECK(ws_keyfocus_holder(srv, &dflt) != 5);
	}
	/* cursor hide counts are per connection; force show clears one; obscure ends with the next mouse move */
	{
		CHECK(ws_cursor_visible(srv));
		ws_cursor_hide(srv, 7); ws_cursor_hide(srv, 7); ws_cursor_hide(srv, 8);
		ws_cursor_unhide(srv, 7, 0); CHECK(!ws_cursor_visible(srv));
		ws_cursor_unhide(srv, 7, 1); CHECK(!ws_cursor_visible(srv));                                 /* 8 still hides it */
		ws_cursor_unhide(srv, 8, 0); CHECK(ws_cursor_visible(srv));
		ws_cursor_unhide(srv, 8, 0); CHECK(ws_cursor_visible(srv));                                  /* never below zero */
		ws_cursor_obscure(srv, 7); CHECK(!ws_cursor_visible(srv));
		ws_server_mouse(srv, 11, 12, 0); CHECK(ws_cursor_visible(srv));
		ws_cursor_hide(srv, 9); ws_release_owner(srv, 9); CHECK(ws_cursor_visible(srv));             /* its hides die with it */
	}
	ws_server_drop_content(srv, content);
	memset(&l, 0, sizeof l); ws_server_walk(srv, on_visit, &l);
	CHECK(l.v[1].pixels != content && l.v[1].buffer_id == 0);
	ws_surface_free(content);
	ws_server_free(srv);
}


/* rounded corners: a window with a corner radius of 16 loses its corner pixels, keeps the rest */
static void test_corners(void)
{
	ws_server *srv = ws_server_new(100, 100);
	ws_surface *scr = ws_surface_new(100, 100);
	ws_wid w = ws_create_window(srv, (ws_rect){ 10, 10, 60, 60 });
	ws_fill(ws_window_backing(srv, w), (ws_rect){ 0, 0, 60, 60 }, 1, 0, 0, 1);
	ws_order_window(srv, w, WS_ABOVE, 0);
	ws_set_window_shadow(srv, w, 16, 1);
	ws_compose_scene(srv, scr);
	#define CP(x, y) (*(uint32_t *)(scr->px + (size_t)(y) * scr->stride + (size_t)(x) * 4))
	CHECK(CP(10, 10) != 0xffff0000u);                      /* the corner pixel is cut */
	CHECK(CP(40, 40) == 0xffff0000u && CP(12, 40) == 0xffff0000u && CP(40, 12) == 0xffff0000u);
	ws_surface_free(scr); ws_server_free(srv);
}

/* screen zoom: a 10x10 red square at the centre of a 100x100 screen covers 20x20 at scale 2 */
static void test_zoom(void)
{
	ws_server *srv = ws_server_new(100, 100);
	ws_surface *scr = ws_surface_new(100, 100);
	ws_wid w = ws_create_window(srv, (ws_rect){ 45, 45, 10, 10 });
	ws_fill(ws_window_backing(srv, w), (ws_rect){ 0, 0, 10, 10 }, 1, 0, 0, 1);
	ws_order_window(srv, w, WS_ABOVE, 0);
	ws_compose_scene(srv, scr);
	#define ZP(x, y) (*(uint32_t *)(scr->px + (size_t)(y) * scr->stride + (size_t)(x) * 4))
	CHECK(ZP(42, 50) != 0xffff0000u && ZP(50, 50) == 0xffff0000u);
	CHECK(ws_server_set_zoom(srv, 2.0f, 50, 50) == 0);
	ws_compose_scene(srv, scr);
	CHECK(ZP(42, 50) == 0xffff0000u && ZP(58, 50) == 0xffff0000u && ZP(38, 50) != 0xffff0000u && ZP(62, 50) != 0xffff0000u);
	CHECK(ws_server_set_zoom(srv, 1.0f, 0, 0) == 0);
	ws_compose_scene(srv, scr);
	CHECK(ZP(42, 50) != 0xffff0000u && ZP(50, 50) == 0xffff0000u);
	ws_surface_free(scr); ws_server_free(srv);
}

/* CIColorInvert: an opaque red window reads cyan */
static void test_invert(void)
{
	ws_server *srv = ws_server_new(100, 100);
	ws_surface *scr = ws_surface_new(100, 100);
	ws_wid w = ws_create_window(srv, (ws_rect){ 10, 10, 40, 40 });
	ws_fill(ws_window_backing(srv, w), (ws_rect){ 0, 0, 40, 40 }, 1, 0, 0, 1);
	ws_order_window(srv, w, WS_ABOVE, 0);
	CHECK(ws_set_window_filter(srv, w, 2) == 0);
	ws_compose_scene(srv, scr);
	CHECK(*(uint32_t *)(scr->px + 20 * scr->stride + 20 * 4) == 0xff00ffffu);
	CHECK(ws_set_window_filter(srv, w, 0) == 0);
	ws_compose_scene(srv, scr);
	CHECK(*(uint32_t *)(scr->px + 20 * scr->stride + 20 * 4) == 0xffff0000u);
	ws_surface_free(scr); ws_server_free(srv);
}

/* SetWindowListBrightness: the colour of an opaque window is multiplied, the alpha stays */
static void test_brightness(void)
{
	ws_server *srv = ws_server_new(100, 100);
	ws_surface *scr = ws_surface_new(100, 100);
	ws_wid w = ws_create_window(srv, (ws_rect){ 10, 10, 40, 40 });
	ws_fill(ws_window_backing(srv, w), (ws_rect){ 0, 0, 40, 40 }, 1, 0.5f, 0, 1);
	ws_order_window(srv, w, WS_ABOVE, 0);
	CHECK(ws_set_window_brightness(srv, w, 0.5f) == 0);
	ws_compose_scene(srv, scr);
	uint32_t p = *(uint32_t *)(scr->px + 20 * scr->stride + 20 * 4);
	CHECK((p >> 24) == 0xff && abs((int)((p >> 16) & 0xff) - 128) <= 1 && abs((int)((p >> 8) & 0xff) - 64) <= 1 && (p & 0xff) == 0);
	CHECK(ws_set_window_brightness(srv, w, 1.0f) == 0);
	ws_compose_scene(srv, scr);
	CHECK(*(uint32_t *)(scr->px + 20 * scr->stride + 20 * 4) == 0xffff8000u || (*(uint32_t *)(scr->px + 20 * scr->stride + 20 * 4) & 0xffff0000u) == 0xffff0000u);
	ws_surface_free(scr); ws_server_free(srv);
}

/* SetWindowListGlobalClipShape: the window shows only inside the screen rectangles, nothing is clipped when the shape is removed */
static void test_global_clip(void)
{
	ws_server *srv = ws_server_new(100, 100);
	ws_surface *scr = ws_surface_new(100, 100);
	ws_wid w = ws_create_window(srv, (ws_rect){ 10, 10, 40, 40 });
	ws_fill(ws_window_backing(srv, w), (ws_rect){ 0, 0, 40, 40 }, 1, 0, 0, 1);
	ws_order_window(srv, w, WS_ABOVE, 0);
	ws_rect cl = { 10, 10, 20, 20 };
	CHECK(ws_set_window_global_clip(srv, w, &cl, 1) == 0);
	ws_compose_scene(srv, scr);
	CHECK(*(uint32_t *)(scr->px + 20 * scr->stride + 20 * 4) == 0xffff0000u);
	CHECK(*(uint32_t *)(scr->px + 40 * scr->stride + 40 * 4) != 0xffff0000u);
	CHECK(ws_set_window_global_clip(srv, w, NULL, 0) == 0);
	ws_compose_scene(srv, scr);
	CHECK(*(uint32_t *)(scr->px + 40 * scr->stride + 40 * 4) == 0xffff0000u);
	ws_surface_free(scr); ws_server_free(srv);
}

/* DisplayFade: an instant fade to red at full blend turns every pixel red; half blend moves it half way; end blend 0 gives the screen back */
static void test_display_fade(void)
{
	ws_server *srv = ws_server_new(100, 100);
	ws_surface *scr = ws_surface_new(100, 100);
	ws_wid w = ws_create_window(srv, (ws_rect){ 10, 10, 40, 40 });
	ws_fill(ws_window_backing(srv, w), (ws_rect){ 0, 0, 40, 40 }, 0, 0, 1, 1);
	ws_order_window(srv, w, WS_ABOVE, 0);
	ws_display_fade(srv, 0, 0, 0.5, 1, 0, 0);
	ws_compose_scene(srv, scr);
	uint32_t p = *(uint32_t *)(scr->px + 20 * scr->stride + 20 * 4);
	CHECK(abs((int)((p >> 16) & 0xff) - 128) <= 2 && abs((int)(p & 0xff) - 127) <= 2);
	ws_display_fade(srv, 0, 0, 1, 1, 0, 0);
	ws_compose_scene(srv, scr);
	CHECK(*(uint32_t *)(scr->px + 20 * scr->stride + 20 * 4) == 0xffff0000u);
	ws_display_fade(srv, 0, 0, 0, 1, 0, 0);
	ws_compose_scene(srv, scr);
	CHECK(*(uint32_t *)(scr->px + 20 * scr->stride + 20 * 4) == 0xff0000ffu);
	ws_surface_free(scr); ws_server_free(srv);
}

/* SetWindowCaptureExcludeShape: the excluded rectangle of a window is cleared in a capture, the rest is kept */
static void test_capture_exclude(void)
{
	ws_server *srv = ws_server_new(100, 100);
	ws_surface *scr = ws_surface_new(100, 100);
	ws_wid w = ws_create_window(srv, (ws_rect){ 10, 10, 40, 40 });
	ws_fill(ws_window_backing(srv, w), (ws_rect){ 0, 0, 40, 40 }, 1, 0, 0, 1);
	ws_order_window(srv, w, WS_ABOVE, 0);
	ws_compose_scene(srv, scr);
	ws_rect ex = { 5, 5, 10, 10 };
	CHECK(ws_set_window_capture_exclude(srv, w, &ex, 1) == 0);
	ws_surface *cap = ws_surface_new(100, 100); ws_copy(cap, 0, 0, scr, (ws_rect){ 0, 0, 100, 100 });
	ws_capture_apply_exclusions(srv, cap, 0, 0);
	CHECK(*(uint32_t *)(cap->px + 20 * cap->stride + 20 * 4) == 0u);                       /* (15..25) in the screen */
	CHECK(*(uint32_t *)(cap->px + 40 * cap->stride + 40 * 4) == 0xffff0000u);
	ws_surface_free(cap); ws_surface_free(scr); ws_server_free(srv);
}

/* SetWindowWarp: a mesh that squeezes a 40x40 window into the left half of its frame (x and y are screen positions, u and v the place in the window) */
static void test_warp(void)
{
	ws_server *srv = ws_server_new(100, 100);
	ws_surface *scr = ws_surface_new(100, 100);
	ws_wid w = ws_create_window(srv, (ws_rect){ 10, 10, 40, 40 });
	ws_fill(ws_window_backing(srv, w), (ws_rect){ 0, 0, 40, 40 }, 1, 0, 0, 1);
	ws_order_window(srv, w, WS_ABOVE, 0);
	/* srcX srcY dstX dstY per point, y up: the 40x40 window at (10,10) squeezed into x 10..30 (the screen is 100 high: y up 50 is row 50 from the top) */
	float mesh[4 * 4] = { 0, 0, 10, 50,   40, 0, 30, 50,   0, 40, 10, 90,   40, 40, 30, 90 };
	CHECK(ws_set_window_warp(srv, w, 2, 2, mesh) == 0);
	ws_compose_scene(srv, scr);
	if (getenv("WARP_DUMP")) for (int y = 0; y < 100; y += 5) { for (int x = 0; x < 60; x += 3) putchar(*(uint32_t *)(scr->px + y * scr->stride + x * 4) == 0xffff0000u ? '#' : '.'); putchar('\n'); }
	CHECK(*(uint32_t *)(scr->px + 30 * scr->stride + 20 * 4) == 0xffff0000u);               /* inside the squeezed window */
	CHECK(*(uint32_t *)(scr->px + 30 * scr->stride + 40 * 4) != 0xffff0000u);               /* where the window was, now empty */
	CHECK(ws_set_window_warp(srv, w, 0, 0, NULL) == 0);
	ws_compose_scene(srv, scr);
	CHECK(*(uint32_t *)(scr->px + 30 * scr->stride + 40 * 4) == 0xffff0000u);
	ws_surface_free(scr); ws_server_free(srv);
}

/* SetWindowTransform: a 40x40 red window scaled 2x about its centre covers 80x80, translation moves it */
static void test_transform(void)
{
	ws_server *srv = ws_server_new(200, 200);
	ws_surface *scr = ws_surface_new(200, 200);
	ws_wid w = ws_create_window(srv, (ws_rect){ 80, 80, 40, 40 });
	ws_fill(ws_window_backing(srv, w), (ws_rect){ 0, 0, 40, 40 }, 1, 0, 0, 1);
	ws_order_window(srv, w, WS_ABOVE, 0);
	float m[6] = { 2, 0, 0, 2, 0, 0 };
	CHECK(ws_set_window_transform(srv, w, m) == 0);
	ws_compose_scene(srv, scr);
	#define PX(x, y) (*(uint32_t *)(scr->px + (size_t)(y) * scr->stride + (size_t)(x) * 4))
	CHECK(PX(65, 100) == 0xffff0000u && PX(134, 100) == 0xffff0000u && PX(100, 65) == 0xffff0000u);
	CHECK(PX(55, 100) != 0xffff0000u && PX(145, 100) != 0xffff0000u);
	m[0] = m[3] = 1; m[4] = 50;
	CHECK(ws_set_window_transform(srv, w, m) == 0);
	ws_compose_scene(srv, scr);
	CHECK(PX(150, 100) == 0xffff0000u && PX(100, 100) != 0xffff0000u);
	m[4] = 0; CHECK(ws_set_window_transform(srv, w, m) == 0);
	ws_compose_scene(srv, scr);
	CHECK(PX(100, 100) == 0xffff0000u && PX(65, 100) != 0xffff0000u);
	m[0] = NAN; CHECK(ws_set_window_transform(srv, w, m) == -1);
	ws_surface_free(scr); ws_server_free(srv);
}

/* backdrop blur: a half-transparent window with blur radius shows a blurred copy of what is behind it */
static void test_blur(void)
{
	ws_server *srv = ws_server_new(120, 60);
	ws_surface *scr = ws_surface_new(120, 60);
	ws_wid back = ws_create_window(srv, (ws_rect){ 0, 0, 120, 60 });
	ws_surface *bs = ws_window_backing(srv, back);
	for (int y = 0; y < 60; y++) for (int x = 0; x < 120; x++) { uint8_t *p = bs->px + (size_t)y * bs->stride + (size_t)x * 4; int on = x < 60; p[0] = p[1] = p[2] = on ? 255 : 0; p[3] = 255; }
	ws_order_window(srv, back, WS_ABOVE, 0);
	ws_wid glass = ws_create_window(srv, (ws_rect){ 30, 10, 60, 40 });
	ws_surface *gs = ws_window_backing(srv, glass);
	memset(gs->px, 0, gs->stride * (size_t)gs->h);                                  /* fully transparent glass */
	ws_order_window(srv, glass, WS_ABOVE, 0);
	ws_compose_scene(srv, scr);
	int edge = scr->px[(size_t)30 * scr->stride + 59 * 4];                          /* the sharp edge between white and black, no blur yet */
	CHECK(edge == 255 || edge == 0);
	CHECK(ws_set_window_blur(srv, glass, 10, 0, 0.0f) == 0);
	int r = 0, f = 0; float a = 0; CHECK(ws_window_blur(srv, glass, &r, &f, &a) == 0 && r == 10);
	ws_set_window_blur(srv, glass, 99, 0, 0.0f); ws_window_blur(srv, glass, &r, &f, &a); CHECK(r == 60);   /* clamped */
	ws_set_window_blur(srv, glass, 10, 0, 0.0f);
	ws_compose_scene(srv, scr);
	int mid = scr->px[(size_t)30 * scr->stride + 59 * 4];                           /* the edge is now smeared: strictly between the extremes */
	int far_left = scr->px[(size_t)30 * scr->stride + 32 * 4], outside = scr->px[(size_t)5 * scr->stride + 59 * 4];
	CHECK(mid > 20 && mid < 235);
	CHECK(far_left > 200);                                                            /* still mostly white inside the glass on the white side */
	CHECK(outside == 255);                                                            /* outside the glass nothing changes */
	CHECK(ws_server_has_blur(srv));
	ws_surface_free(scr);
	ws_server_free(srv);
}


/* the glass material: a colourful backdrop under a transparent window with a glass rectangle; the inside is blurred and more saturated, the corners outside the rounded rectangle are untouched, the rim is lighter */
static void test_glass(void)
{
	ws_server *srv = ws_server_new(400, 200);
	ws_wid bg = ws_create_window(srv, (ws_rect){ 0, 0, 400, 200 }), gl = ws_create_window(srv, (ws_rect){ 50, 60, 300, 80 });
	ws_surface *b = ws_window_backing(srv, bg);
	for (int y = 0; y < 200; y++) for (int x = 0; x < 400; x++) { uint8_t *p = (uint8_t *)at(b, x, y); int chk = ((x / 20) + (y / 20)) & 1; p[0] = chk ? 200 : 30; p[1] = chk ? 60 : 180; p[2] = chk ? 40 : 220; p[3] = 255; }
	ws_order_window(srv, bg, WS_ABOVE, 0); ws_order_window(srv, gl, WS_ABOVE, 0);
	ws_surface *plain = ws_surface_new(400, 200); ws_compose_scene(srv, plain);
	ws_set_window_glass(srv, gl, (ws_rect){ 0, 0, 300, 80 }, 24, 1);
	ws_surface *out = ws_surface_new(400, 200); ws_compose_scene(srv, out);
	CHECK(memcmp(at(out, 5, 5), at(plain, 5, 5), 4) == 0);                                   /* outside the glass: unchanged */
	CHECK(memcmp(at(out, 52, 62), at(plain, 52, 62), 4) == 0);                               /* the corner outside the rounded rectangle */
	int diff = 0; for (int c = 0; c < 3; c++) diff += abs(at(out, 200, 100)[c] - at(plain, 200, 100)[c]); CHECK(diff > 6);   /* inside: blurred */
	int d1 = abs(at(out, 200, 100)[0] - at(out, 220, 100)[0]) + abs(at(out, 200, 100)[1] - at(out, 220, 100)[1]);
	int d0 = abs(at(plain, 200, 100)[0] - at(plain, 220, 100)[0]) + abs(at(plain, 200, 100)[1] - at(plain, 220, 100)[1]);
	CHECK(d1 <= d0 + 20);                                                                    /* no blur inside: the checkerboard stays about as sharp */
	CHECK(at(out, 200, 61)[0] > at(out, 200, 63)[0] || at(out, 200, 61)[1] > at(out, 200, 63)[1]);   /* the top rim is a lighter line */
	if (getenv("GLASS_PPM")) ws_write_ppm(out, getenv("GLASS_PPM"));
	ws_surface_free(plain); ws_surface_free(out); ws_server_free(srv);
}


/* the context menu material (glass mode 5) against what the real Mac drew over uniform backdrops (screen captures of an NSMenu over known colours) */
static void test_menu_material(void)
{
	static const struct { int bg[3], want[3]; } t[] = { { { 0, 0, 0 }, { 31, 31, 31 } }, { { 64, 64, 64 }, { 84, 84, 84 } }, { { 128, 128, 128 }, { 123, 123, 123 } }, { { 191, 191, 191 }, { 146, 146, 146 } },
		{ { 255, 255, 255 }, { 155, 155, 155 } }, { { 255, 0, 0 }, { 255, 15, 15 } }, { { 0, 0, 255 }, { 26, 26, 255 } }, { { 204, 102, 51 }, { 206, 101, 49 } } };
	for (unsigned k = 0; k < sizeof t / sizeof t[0]; k++) {
		ws_server *srv = ws_server_new(300, 200);
		ws_wid bg = ws_create_window(srv, (ws_rect){ 0, 0, 300, 200 }), m = ws_create_window(srv, (ws_rect){ 60, 40, 111, 93 });
		ws_surface *b = ws_window_backing(srv, bg);
		for (int y = 0; y < 200; y++) for (int x = 0; x < 300; x++) { uint8_t *p = (uint8_t *)at(b, x, y); p[0] = (uint8_t)t[k].bg[2]; p[1] = (uint8_t)t[k].bg[1]; p[2] = (uint8_t)t[k].bg[0]; p[3] = 255; }
		ws_order_window(srv, bg, WS_ABOVE, 0); ws_order_window(srv, m, WS_ABOVE, 0);
		ws_set_window_glass(srv, m, (ws_rect){ 0, 0, 111, 93 }, 12, 5);
		ws_surface *out = ws_surface_new(300, 200); ws_compose_scene(srv, out);
		const uint8_t *c = at(out, 60 + 55, 40 + 46);
		for (int ch = 0; ch < 3; ch++) CHECK(abs(c[2 - ch] - t[k].want[ch]) <= 12);              /* the fit is good to a few levels; saturated colours to a dozen */
		if (k == 0) { CHECK(at(out, 60 + 55, 40)[0] > at(out, 60 + 55, 40 + 3)[0] + 20); CHECK(at(out, 60, 40 + 46)[0] > at(out, 60 + 8, 40 + 46)[0] + 8); }   /* the rim: strong on the top edge, weaker on the sides */
		CHECK(memcmp(at(out, 5, 5), at(b, 5, 5), 4) == 0);
		ws_surface_free(out); ws_server_free(srv);
	}
}

/* GLASS_DEMO=file.ppm: the pattern used to measure the real Dock (stripes, lines, text-like marks) behind a 1160 x 78 glass bar of radius 18 */
static void glass_demo(const char *path)
{
	ws_server *srv = ws_server_new(1400, 200);
	ws_wid bg = ws_create_window(srv, (ws_rect){ 0, 0, 1400, 200 }), gl = ws_create_window(srv, (ws_rect){ 0, 0, 1400, 200 });
	ws_surface *b = ws_window_backing(srv, bg);
	for (int y = 0; y < 200; y++) for (int x = 0; x < 1400; x++) {
		uint8_t *p = (uint8_t *)at(b, x, y); int stripe = (x % 40) < 18; float h = ((x / 40) % 12) / 12.0f * 6.0f; int k = (int)h; float f = h - k;
		float rgb[3] = { 1, 1, 1 }; if (stripe) { float v[6][3] = { { 1, f, 0 }, { 1 - f, 1, 0 }, { 0, 1, f }, { 0, 1 - f, 1 }, { f, 0, 1 }, { 1, 0, 1 - f } }; for (int c = 0; c < 3; c++) rgb[c] = 0.1f + 0.85f * v[k % 6][c]; }
		if (y % 14 < 2) rgb[0] = rgb[1] = rgb[2] = 0;
		p[0] = (uint8_t)(rgb[2] * 255); p[1] = (uint8_t)(rgb[1] * 255); p[2] = (uint8_t)(rgb[0] * 255); p[3] = 255;
	}
	ws_order_window(srv, bg, WS_ABOVE, 0); ws_order_window(srv, gl, WS_ABOVE, 0);
	ws_set_window_glass(srv, gl, (ws_rect){ 100, 62, 1160, 78 }, 18, 1);
	ws_surface *out = ws_surface_new(1400, 200); ws_compose_scene(srv, out); ws_write_ppm(out, path);
	ws_surface_free(out); ws_server_free(srv);
}

int main(void)
{
	if (getenv("GLASS_DEMO")) { glass_demo(getenv("GLASS_DEMO")); return 0; }
	test_glass(); test_menu_material();
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
	CHECK(at(scr, 2, 2)[0] == 37 && at(scr, 2, 2)[1] == 37 && at(scr, 2, 2)[2] == 37);   /* desktop #252525 */
	{ /* system-wide frame counter and its overlay */
		unsigned long before = ws_fps_total();
		for (int i = 0; i < 5; i++) ws_fps_frame(2.0);
		CHECK(ws_fps_total() == before + 5);
		ws_surface *o = ws_surface_new(300, 80);
		ws_fill(o, (ws_rect){ 0, 0, 300, 80 }, 0, 0, 0, 255);
		ws_draw_fps(o);
		int lit = 0; for (int y = 0; y < o->h; y++) for (int x = 0; x < o->w; x++) if (o->px[(size_t)y * o->stride + x * 4] > 200) lit++;
		CHECK(lit > 0);                                          /* the overlay sits in the top right corner, below the menu bar */
		ws_surface_free(o);
	}
	{ /* standard cursor shapes */
		uint32_t ser = ws_cursor_serial(srv); int hx, hy;
		ws_server_set_cursor_shape(srv, 1);
		CHECK(ws_cursor_serial(srv) != ser);
		const ws_surface *ci = ws_cursor_image(srv, &hx, &hy);
		CHECK(ci && hx == 16 && hy == 16);
		int opaque = 0; for (int y = 0; y < ci->h; y++) for (int x = 0; x < ci->w; x++) if (ci->px[(size_t)y * ci->stride + x * 4 + 3] == 255) opaque++;
		CHECK(opaque > 20);
		for (int k = 2; k < ws_cursor_shape_count(); k++) { ws_surface *sh = ws_cursor_shape_image(k, &hx, &hy); CHECK(sh != NULL); ws_surface_free(sh); }
		ws_server_set_cursor_shape(srv, 0);
	}

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
	while (ws_next_event(srv, a, &ev)); while (ws_next_event(srv, b, &ev)); while (ws_next_event(srv, c, &ev));     /* the focus events of appearing windows (the last one ordered in is the key window) */
	ws_server_mouse(srv, 30, 30, 0);                        /* over a (b is elsewhere) */
	CHECK(ws_next_event(srv, a, &ev) && ev.type == WS_EV_MOUSE_MOVE && ev.x == 10 && ev.y == 10);
	ws_server_mouse(srv, 30, 30, 1);                        /* press on a */
	CHECK(ws_key_window(srv) == a);
	int got_down = 0, got_focus = 0;
	while (ws_next_event(srv, a, &ev)) { if (ev.type == WS_EV_MOUSE_DOWN) got_down = 1; if (ev.type == WS_EV_FOCUS_IN) got_focus = 1; }
	CHECK(got_down && got_focus);
	while (ws_next_event(srv, b, &ev));                     /* b lost the key focus */
	ws_server_mouse(srv, 250, 140, 1);                      /* drag out over b: still goes to a */
	CHECK(ws_next_event(srv, a, &ev) && ev.type == WS_EV_MOUSE_MOVE && ev.x == 230);
	CHECK(!ws_next_event(srv, b, &ev));
	ws_server_mouse(srv, 250, 140, 0);                      /* release */
	ws_server_key(srv, 42, 1);
	CHECK(ws_next_event(srv, a, &ev) && ev.type == WS_EV_MOUSE_UP);
	CHECK(ws_next_event(srv, a, &ev) && ev.type == WS_EV_KEY_DOWN && ev.key == 42);
	/* a cursor shape belongs to the window under the pointer when it was set: leaving that window brings the arrow back */
	ws_server_mouse(srv, 30, 30, 0); ws_server_set_cursor_shape(srv, 3); CHECK(ws_server_cursor_shape(srv) == 3);
	ws_server_mouse(srv, 33, 33, 0); CHECK(ws_server_cursor_shape(srv) == 3);              /* still over a */
	ws_server_mouse(srv, 5, 290, 0); CHECK(ws_server_cursor_shape(srv) == 0);              /* over the desktop */
	/* a window that appears takes the keyboard; the key window going away hands it to the frontmost ordinary window */
	{ ws_wid k1 = ws_create_window(srv, (ws_rect){ 20, 20, 300, 200 }), k2 = ws_create_window(srv, (ws_rect){ 60, 60, 300, 200 });
	  ws_order_window(srv, k1, WS_ABOVE, 0); CHECK(ws_key_window(srv) == k1);
	  ws_order_window(srv, k2, WS_ABOVE, 0); CHECK(ws_key_window(srv) == k2);
	  ws_order_window(srv, k2, WS_OUT, 0); CHECK(ws_key_window(srv) == k1);
	  ws_order_window(srv, k1, WS_OUT, 0); ws_release_window(srv, k1); ws_release_window(srv, k2); }
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
	test_walk(); test_glass(); test_menu_material();
	test_transform();
	test_invert();
	test_brightness();
	test_capture_exclude(); test_global_clip(); test_display_fade();
	test_warp();
	test_zoom();
	test_corners();
	printf(fails ? "%d failures\n" : "all tests passed\n", fails);
	return fails != 0;
}
