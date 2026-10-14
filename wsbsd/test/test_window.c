/* A client that draws a test window through the wsbsd protocol and takes a screenshot. */
#include "ws_client.h"
#include "sls_wire.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

typedef struct { float r, g, b, a; } col;

static float rr(float px, float py, float x, float y, float w, float h, float rad)
{
	float cx = px - (x + w * 0.5f), cy = py - (y + h * 0.5f);
	float qx = fabsf(cx) - (w * 0.5f - rad), qy = fabsf(cy) - (h * 0.5f - rad);
	float ox = qx > 0 ? qx : 0, oy = qy > 0 ? qy : 0;
	float d = sqrtf(ox * ox + oy * oy) + (qx > qy ? (qx < 0 ? qx : 0) : (qy < 0 ? qy : 0)) - rad;
	float c = 0.5f - d;
	return c < 0 ? 0 : c > 1 ? 1 : c;
}

/* source-over of a straight-alpha colour with coverage onto premultiplied BGRA */
static void blend(ws_surface *s, int x, int y, col c, float cov)
{
	if (x < 0 || y < 0 || x >= s->w || y >= s->h) return;
	float a = c.a * cov;
	if (a <= 0) return;
	uint8_t *p = s->px + (size_t)y * s->stride + (size_t)x * 4;
	float inv = 1.0f - a;
	p[0] = (uint8_t)(c.b * a * 255.0f + p[0] * inv + 0.5f);
	p[1] = (uint8_t)(c.g * a * 255.0f + p[1] * inv + 0.5f);
	p[2] = (uint8_t)(c.r * a * 255.0f + p[2] * inv + 0.5f);
	p[3] = (uint8_t)(a * 255.0f + p[3] * inv + 0.5f);
}

static void rrect(ws_surface *s, float x, float y, float w, float h, float rad, col c)
{
	for (int j = (int)y - 1; j <= (int)(y + h) + 1; j++)
		for (int i = (int)x - 1; i <= (int)(x + w) + 1; i++)
			blend(s, i, j, c, rr(i + 0.5f, j + 0.5f, x, y, w, h, rad));
}

static void vgrad(ws_surface *s, int x, int y, int w, int h, col top, col bot)
{
	for (int j = 0; j < h; j++) {
		float t = h > 1 ? (float)j / (float)(h - 1) : 0;
		col c = { top.r + (bot.r - top.r) * t, top.g + (bot.g - top.g) * t, top.b + (bot.b - top.b) * t, 1 };
		for (int i = 0; i < w; i++) blend(s, x + i, y + j, c, 1);
	}
}

/* multiply the whole surface by a rounded-rect mask: gives the window its rounded corners */
static void mask_corners(ws_surface *s, float rad)
{
	for (int j = 0; j < s->h; j++)
		for (int i = 0; i < s->w; i++) {
			float m = rr(i + 0.5f, j + 0.5f, 0, 0, (float)s->w, (float)s->h, rad);
			if (m >= 1) continue;
			uint8_t *p = s->px + (size_t)j * s->stride + (size_t)i * 4;
			for (int k = 0; k < 4; k++) p[k] = (uint8_t)(p[k] * m + 0.5f);
		}
}

static void draw_main(ws_surface *s)
{
	int W = s->w, H = s->h;
	col white = { 1, 1, 1, 1 };
	for (int j = 0; j < H; j++) for (int i = 0; i < W; i++) blend(s, i, j, white, 1);
	/* sidebar */
	col side = { 0.93f, 0.94f, 0.96f, 1 };
	for (int j = 32; j < H; j++) for (int i = 0; i < 170; i++) blend(s, i, j, side, 1);
	col sel = { 0.0f, 0.478f, 1.0f, 0.18f };
	rrect(s, 10, 52, 150, 28, 8, sel);
	col grey = { 0.55f, 0.57f, 0.62f, 1 }, dk = { 0.2f, 0.22f, 0.26f, 1 };
	for (int k = 0; k < 5; k++) {
		rrect(s, 22, 58 + k * 36, 16, 16, 4, k == 0 ? (col){ 0, 0.478f, 1, 1 } : grey);
		rrect(s, 48, 62 + k * 36, 70 + (k * 17) % 40, 8, 4, k == 0 ? dk : grey);
	}
	/* title bar */
	vgrad(s, 0, 0, W, 32, (col){ 0.96f, 0.96f, 0.97f, 1 }, (col){ 0.90f, 0.90f, 0.92f, 1 });
	col line = { 0.78f, 0.78f, 0.80f, 1 };
	for (int i = 0; i < W; i++) blend(s, i, 31, line, 1);
	col lights[3] = { { 1.0f, 0.37f, 0.34f, 1 }, { 1.0f, 0.74f, 0.18f, 1 }, { 0.16f, 0.79f, 0.25f, 1 } };
	for (int k = 0; k < 3; k++) rrect(s, 16.0f + 23.0f * k - 7, 16 - 7, 14, 14, 7, lights[k]);
	rrect(s, W / 2 - 60, 12, 120, 8, 4, grey);   /* title placeholder */
	/* content */
	rrect(s, 200, 60, 220, 14, 7, dk);
	rrect(s, 200, 86, 330, 8, 4, grey);
	rrect(s, 200, 104, 280, 8, 4, grey);
	rrect(s, 200, 150, 110, 32, 8, (col){ 0, 0.478f, 1, 1 });          /* default button */
	rrect(s, 322, 150, 110, 32, 8, (col){ 0.88f, 0.89f, 0.91f, 1 });   /* push button */
	rrect(s, 200, 210, 300, 6, 3, (col){ 0.85f, 0.86f, 0.88f, 1 });    /* progress track */
	rrect(s, 200, 210, 190, 6, 3, (col){ 0, 0.478f, 1, 1 });
	rrect(s, 200, 250, 300, 4, 2, (col){ 0.85f, 0.86f, 0.88f, 1 });    /* slider */
	rrect(s, 200, 250, 150, 4, 2, (col){ 0, 0.478f, 1, 1 });
	rrect(s, 342, 243, 18, 18, 9, (col){ 1, 1, 1, 1 });
	rrect(s, 340, 241, 22, 22, 11, (col){ 0, 0, 0, 0.12f });
	rrect(s, 342, 243, 18, 18, 9, (col){ 1, 1, 1, 1 });
	rrect(s, 200, 292, 46, 28, 14, (col){ 0.20f, 0.78f, 0.35f, 1 });   /* switch on */
	rrect(s, 220, 295, 22, 22, 11, (col){ 1, 1, 1, 1 });
	mask_corners(s, 12);
}

static void draw_back(ws_surface *s)
{
	int W = s->w, H = s->h;
	vgrad(s, 0, 0, W, H, (col){ 0.20f, 0.22f, 0.27f, 1 }, (col){ 0.12f, 0.13f, 0.17f, 1 });
	col lights[3] = { { 1.0f, 0.37f, 0.34f, 1 }, { 1.0f, 0.74f, 0.18f, 1 }, { 0.5f, 0.5f, 0.52f, 1 } };
	for (int k = 0; k < 3; k++) rrect(s, 16.0f + 23.0f * k - 7, 16 - 7, 14, 14, 7, lights[k]);
	for (int k = 0; k < 6; k++) rrect(s, 24, 60 + k * 30, 200 + (k * 53) % 160, 8, 4, (col){ 0.45f, 0.78f, 0.55f, 0.9f });
	mask_corners(s, 12);
}

static void draw_hud(ws_surface *s)
{
	for (int j = 0; j < s->h; j++) for (int i = 0; i < s->w; i++) blend(s, i, j, (col){ 0.08f, 0.09f, 0.12f, 1 }, 1);
	rrect(s, 24, 28, 90, 12, 6, (col){ 1, 1, 1, 0.9f });
	rrect(s, 24, 54, 170, 8, 4, (col){ 1, 1, 1, 0.5f });
	rrect(s, 24, 74, 140, 8, 4, (col){ 1, 1, 1, 0.5f });
	mask_corners(s, 20);
}

int main(int argc, char **argv)
{
	const char *out = argc > 1 ? argv[1] : "window.ppm";
	ws_conn *c = ws_connect(NULL);
	if (!c) { fprintf(stderr, "test_window: cannot connect to wsd\n"); return 1; }
	ws_win back, main_w, hud, surf_w;
	if (ws_win_create(c, (ws_rect){ 70, 330, 520, 300 }, 0, &back) ||
	    ws_win_create(c, (ws_rect){ 230, 110, 700, 440 }, 0, &main_w) ||
	    ws_win_create(c, (ws_rect){ 800, 520, 280, 130 }, 0, &hud)) { fprintf(stderr, "test_window: create failed\n"); return 1; }
	draw_back(back.px); draw_main(main_w.px); draw_hud(hud.px);

	/* a window whose pixels arrive through the shared-buffer contract: allocate, draw, register, add a surface, bind, flush */
	{
		const int SW = 320, SH = 200;
		if (ws_win_create(c, (ws_rect){ 900, 60, SW, SH }, 0, &surf_w)) { fprintf(stderr, "test_window: surface window create failed\n"); return 1; }
		ws_cbuf cb;
		if (ws_cbuf_create(c, SW, SH, &cb)) { fprintf(stderr, "test_window: buffer create/import failed\n"); return 1; }
		printf("buffer %u: %s, %dx%d, stride %u (w*4 = %d, aligned to 128), format AR24\n", cb.id, cb.buf.kind == WS_BUF_DMABUF ? "dma-buf" : "shm", cb.buf.w, cb.buf.h, cb.buf.stride[0], SW * 4);
		ws_surface *px = cb.buf.cpu;
		for (int y = 0; y < SH; y++) {                      /* horizontal blue-to-orange gradient with a lighter band at the top */
			uint8_t *row = px->px + (size_t)y * px->stride;
			for (int x = 0; x < SW; x++) {
				float t = (float)x / (SW - 1), v = (float)y / (SH - 1);
				uint8_t r = (uint8_t)(255 * (0.15f + 0.85f * t)), g = (uint8_t)(255 * (0.45f + 0.15f * (1 - t)) * (0.7f + 0.3f * (1 - v))), b = (uint8_t)(255 * (0.95f - 0.8f * t));
				row[x * 4 + 0] = b; row[x * 4 + 1] = g; row[x * 4 + 2] = r; row[x * 4 + 3] = 255;
			}
		}
		/* rounded corners via alpha, premultiplied */
		for (int y = 0; y < SH; y++) for (int x = 0; x < SW; x++) {
			float m = rr(x + 0.5f, y + 0.5f, 0, 0, (float)SW, (float)SH, 14);
			if (m < 1) { uint8_t *p4 = px->px + (size_t)y * px->stride + (size_t)x * 4; for (int k = 0; k < 4; k++) p4[k] = (uint8_t)(p4[k] * m + 0.5f); }
		}
		uint32_t sid = 0;
		if (ws_surface_add(c, &surf_w, &sid) || !sid) { fprintf(stderr, "test_window: AddSurface failed\n"); return 1; }
		if (ws_surface_bind_buffer(c, &surf_w, sid, &cb)) { fprintf(stderr, "test_window: BindSurface failed\n"); return 1; }
		int kind = -1; uint32_t ba = 99, bb = 0;
		if (ws_surface_binding(c, &surf_w, sid, &kind, &ba, &bb) || kind != SLS_BIND_CONTEXT || bb != cb.id) { fprintf(stderr, "test_window: GetSurfaceBinding mismatch\n"); return 1; }
		ws_rect dirty = { 0, 0, SW, SH };
		if (ws_surface_flush(c, &surf_w, sid, &dirty)) { fprintf(stderr, "test_window: FlushSurface failed\n"); return 1; }
		printf("surface %u bound to buffer %u and committed\n", sid, cb.id);
		ws_win_shadow(c, &surf_w, 14, 1);
		ws_win_order(c, &surf_w, WS_ABOVE, 0);
	}
	ws_win_shadow(c, &back, 12, 1);
	ws_win_shadow(c, &main_w, 12, 1);
	ws_win_shadow(c, &hud, 20, 1);
	ws_win_alpha(c, &hud, 0.88f);
	ws_win_order(c, &back, WS_ABOVE, 0);
	ws_win_order(c, &main_w, WS_ABOVE, 0);
	ws_win_order(c, &hud, WS_ABOVE, 0);
	ws_win_order(c, &main_w, WS_ABOVE, 0);          /* focus the test window: it takes the active shadow */
	ws_win_flush(c, &back); ws_win_flush(c, &main_w); ws_win_flush(c, &hud);
	/* drive the input path: hover, click the test window, press a key, then read the events back */
	ws_inject_mouse(c, 520, 330, 0);
	ws_inject_mouse(c, 520, 330, 1);
	ws_inject_mouse(c, 520, 330, 0);
	ws_inject_key(c, 36, 1);
	{
		ws_event e; int move = 0, down = 0, up = 0, key = 0, focus = 0;
		while (ws_poll_event(c, &main_w, &e)) {
			move += e.type == WS_EV_MOUSE_MOVE; down += e.type == WS_EV_MOUSE_DOWN; up += e.type == WS_EV_MOUSE_UP;
			key += e.type == WS_EV_KEY_DOWN; focus += e.type == WS_EV_FOCUS_IN;
		}
		printf("events on test window: move=%d down=%d up=%d key=%d focus_in=%d\n", move, down, up, key, focus);
		if (!(move && down && up && key && focus)) { fprintf(stderr, "test_window: input events missing\n"); return 1; }
	}
	ws_wid hit = ws_win_find(c, 400, 300);
	printf("window under (400,300): %u (test window is %u)\n", (unsigned)hit, (unsigned)main_w.id);
	if (ws_screenshot(c, out)) { fprintf(stderr, "test_window: screenshot failed\n"); return 1; }
	printf("wrote %s\n", out);
	ws_win_release(c, &back); ws_win_release(c, &main_w); ws_win_release(c, &hud);
	if (argc > 2) ws_server_quit(c);
	ws_disconnect(c);
	return hit == main_w.id ? 0 : 2;
}
