/* bench_rpc: round trips per second of a cheap request (GetWindowLevel) against a running wsd (WS_SOCKET) */
#include <stdio.h>
#include <time.h>
#include "ws_client.h"
static double now(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec * 1e3 + t.tv_nsec / 1e6; }
int main(void)
{
	ws_conn *c = ws_connect(NULL); if (!c) return 1;
	ws_win w; if (ws_win_create(c, (ws_rect){ 0, 0, 100, 100 }, 3, &w)) return 1;
	int n = 100000, lv = 0; double t0 = now();
	for (int i = 0; i < n; i++) if (ws_win_get_level(c, &w, &lv)) { printf("failed at %d\n", i); return 1; }
	double ms = now() - t0;
	printf("%d round trips in %.0f ms: %.1f us each, %.0f/s\n", n, ms, ms * 1000 / n, n / (ms / 1000));
	return 0;
}
