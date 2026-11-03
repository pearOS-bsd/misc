/* The damage path of the software compositor against the whole-frame reference: a random scene (windows that move, resize, fade, appear, disappear, change order, shadows, blur, glass, content
 * drawn into parts of a window, the pointer) is composed frame after frame on one surface, with damage, and again in full on another; the two must be identical after every frame. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "ws.h"

static unsigned long rng = 88172645463325252UL;
static unsigned rnd(unsigned n) { rng ^= rng << 13; rng ^= rng >> 7; rng ^= rng << 17; return (unsigned)(rng % n); }
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }

int main(int argc, char **argv)
{
	int W = 640, H = 400, frames = argc > 1 ? atoi(argv[1]) : 600, bad = 0, calm = argc > 3 && atoi(argv[3]);       /* calm: small windows, one change a frame, the rare effect (the case the damage path is for) */
	if (argc > 2) rng ^= (unsigned long)atol(argv[2]) * 2654435761UL;
	ws_server *s = ws_server_new(W, H);
	ws_surface *A = ws_surface_new(W, H), *B = ws_surface_new(W, H);
	ws_wid ids[24]; int nid = 0, pointer = 1;
	double tp = 0, tf = 0; long partial = 0;
	for (int f = 0; f < frames; f++) {
		int ops = calm ? 1 : 1 + (int)rnd(3);
		while (ops--) {
			int op = (int)rnd(14); if (calm && (op == 10 || op == 11 || op == 6)) op = 7;
			if (op == 0 && nid < 24) {
				int w = calm ? 40 + (int)rnd(100) : 60 + (int)rnd(300), h = calm ? 30 + (int)rnd(70) : 40 + (int)rnd(220);
				ws_wid id = ws_create_window(s, (ws_rect){ (int)rnd(W) - 40, (int)rnd(H) - 30, w, h });
				ws_surface *b = ws_window_backing(s, id);
				if (b) ws_fill(b, (ws_rect){ 0, 0, w, h }, rnd(100) / 100.0f, rnd(100) / 100.0f, rnd(100) / 100.0f, rnd(4) ? 1.0f : 0.5f);
				if (rnd(2)) ws_set_window_shadow(s, id, 8, 1);
				if (rnd(calm ? 14 : 5) == 0) ws_set_window_blur(s, id, 6 + (int)rnd(14), 0, 1.0f);
				if (rnd(calm ? 16 : 6) == 0) ws_set_window_glass(s, id, (ws_rect){ 4, 4, w - 8, h - 8 }, 12, 1);
				ws_order_window(s, id, WS_ABOVE, 0); ids[nid++] = id;
				ws_window_damage(s, id, NULL);
			} else if (nid) {
				ws_wid id = ids[rnd((unsigned)nid)];
				ws_surface *b = ws_window_backing(s, id);
				switch (op) {
				case 1: case 2: case 3: ws_move_window(s, id, (int)rnd(W) - 40, (int)rnd(H) - 30); break;
				case 4: ws_set_window_alpha(s, id, 0.2f + rnd(80) / 100.0f); break;
				case 5: ws_order_window(s, id, rnd(2) ? WS_ABOVE : WS_BELOW, 0); break;
				case 6: ws_order_window(s, id, rnd(3) ? WS_ABOVE : WS_OUT, 0); if (rnd(2)) ws_order_window(s, id, WS_ABOVE, 0); break;
				case 7: case 8: if (b) { int x = (int)rnd(40), y = (int)rnd(30), w = 10 + (int)rnd(50), h = 10 + (int)rnd(40); ws_fill(b, (ws_rect){ x, y, w, h }, rnd(100) / 100.0f, rnd(100) / 100.0f, rnd(100) / 100.0f, 1.0f); ws_window_damage(s, id, &(ws_rect){ x, y, w, h }); } break;
				case 9: ws_set_window_shadow(s, id, 8, (int)rnd(2)); break;
				case 10: ws_set_window_blur(s, id, rnd(2) ? 0 : 6 + (int)rnd(14), 0, 1.0f); break;
				case 11: { ws_rect fr = { 0, 0, 0, 0 }; (void)fr; ws_set_window_glass(s, id, (ws_rect){ 4, 4, 40, 30 }, 10, (int)rnd(2)); break; }
				case 12: pointer = (int)rnd(4) != 0; ws_server_mouse(s, (int)rnd(W), (int)rnd(H), 0); break;
				case 13: ws_set_window_level(s, id, (int)rnd(3)); break;
				}
			}
		}
		double a = now();
		ws_compose_scene(s, A); if (pointer) ws_draw_cursor(s, A);
		double b = now();
		ws_compose_scene_full(s, B); if (pointer) ws_draw_cursor(s, B);
		double c = now(); tp += b - a; tf += c - b;
		ws_rect pr; if (ws_server_present_rect(s, &pr)) partial++;
		if (memcmp(A->px, B->px, (size_t)A->stride * A->h)) {
			int bx = -1, by = -1;
			for (int y = 0; y < H && bx < 0; y++) for (int x = 0; x < W; x++) if (memcmp(A->px + (size_t)y * A->stride + x * 4, B->px + (size_t)y * B->stride + x * 4, 4)) { bx = x; by = y; break; }
			printf("frame %d: damage path differs from the full frame, first pixel %d,%d\n", f, bx, by);
			if (++bad >= 5) break;
		}
	}
	printf("%s: %d frames, %ld composed partially, damage path %.1f ms total, full %.1f ms total\n", bad ? "FAIL" : "test_damage ok", frames, partial, tp, tf);
	return bad != 0;
}
