/* bench_compose: time of one full software-composed frame with a typical scene (shadows, rounded corners, a blurred translucent panel) at 1920x1080 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "ws.h"

static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }

int main(void)
{
	int W = 1920, H = 1080;
	ws_server *s = ws_server_new(W, H);
	ws_surface *screen = ws_surface_new(W, H);
	for (int i = 0; i < 8; i++) {
		ws_wid id = ws_create_window(s, (ws_rect){ 100 + 120 * i, 80 + 60 * i, 900, 600 });
		ws_surface *b = ws_window_backing(s, id);
		if (b) ws_fill(b, (ws_rect){ 0, 0, 900, 600 }, 0.3f + 0.08f * i, 0.5f, 0.8f - 0.07f * i, i == 5 ? 0.6f : 1.0f);
		ws_set_window_shadow(s, id, 10, 1);
		if (i == 5) ws_set_window_blur(s, id, 20, 0, 1.0f);
		ws_order_window(s, id, WS_ABOVE, 0);
	}
	ws_compose_scene(s, screen);                                      /* warm up shadow caches */
	double t0 = now(); int n = 20;
	for (int i = 0; i < n; i++) { ws_window_damage(s, 1, NULL); ws_compose_scene(s, screen); }
	printf("compose 1920x1080, 8 windows (shadows, blur): %.2f ms/frame\n", (now() - t0) / n);
	return 0;
}
