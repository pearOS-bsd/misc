/* bench_fps: frame rate of a running wsd (WS_SOCKET) with an animated scene: four windows with shadows and glass (blur) that move in circles for BENCH_SECONDS (default 8);
 * prints the mean frame rate and mean frame time the server reports (ws_fps). Used to compare the GL compositor with the software one, on a real GPU or on virgl in a VM. */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <unistd.h>
#include "ws_client.h"

static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }

int main(void)
{
	ws_conn *c = ws_connect(NULL); if (!c) { printf("no connection\n"); return 1; }
	int sw = 1280, sh = 800, secs = getenv("BENCH_SECONDS") ? atoi(getenv("BENCH_SECONDS")) : 8; ws_conn_screen(c, &sw, &sh);
	int nwin = getenv("BENCH_WINDOWS") ? atoi(getenv("BENCH_WINDOWS")) : 4; if (nwin < 1) nwin = 1; if (nwin > 16) nwin = 16;
	int ww = getenv("BENCH_WIDTH") ? atoi(getenv("BENCH_WIDTH")) : 560, wh = ww * 380 / 560;
	ws_win w[16];
	for (int i = 0; i < nwin; i++) {
		if (ws_win_create(c, (ws_rect){ 100 + 40 * i, 100 + 30 * i, ww, wh }, 3, &w[i])) { printf("window %d failed\n", i); return 1; }
		ws_win_shadow(c, &w[i], 12, 1);
		ws_win_glass(c, &w[i], (ws_rect){ 0, 0, ww, wh }, 18, 0);
		ws_win_order(c, &w[i], 1, 0);
	}
	double t0 = now(), sum_fps = 0, sum_ms = 0; int n = 0; double next = t0 + 1000; unsigned long f0 = 0, f1 = 0; int first = 1;
	while (now() - t0 < secs * 1000.0) {
		double t = (now() - t0) / 1000.0;
		for (int i = 0; i < nwin; i++) ws_win_move(c, &w[i], (int)(sw / 2 - ww / 2 + 220 * cos(t * 1.7 + i * 1.6)), (int)(sh / 2 - wh / 2 + 160 * sin(t * 1.3 + i * 1.6)));
		if (now() >= next) { double fps, ms; unsigned long fr; if (!ws_fps(c, &fps, &ms, &fr)) { sum_fps += fps; sum_ms += ms; n++; if (first) { f0 = fr; first = 0; } f1 = fr; } next += 1000; }
	}
	printf("bench_fps: %dx %d px windows on %dx%d, %d s, %d samples, mean %.1f FPS, mean frame time %.2f ms, %lu frames presented\n", nwin, ww, sw, sh, secs, n, n ? sum_fps / n : 0, n ? sum_ms / n : 0, f1 - f0);
	for (int i = 0; i < nwin; i++) ws_win_release(c, &w[i]);
	ws_disconnect(c);
	return 0;
}
