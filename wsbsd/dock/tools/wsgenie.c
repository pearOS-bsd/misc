/* wsgenie: a window with a grid that is minimized into a rectangle with the genie effect, through SetWindowWarp: the mesh comes from dock/genie.c every frame, the way the Dock does it.
 * usage: wsgenie [out-prefix]   (with a prefix a screenshot of frames 0, 5, 10 ... is written as PREFIX-N.ppm) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "ws_client.h"
#include "../genie.h"

int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL); if (!c) { fprintf(stderr, "wsgenie: no wsd\n"); return 1; }
	int sw = 1280, sh = 800; ws_conn_screen(c, &sw, &sh);
	ws_rect f = { 200, 120, 560, 380 }; ws_win win;
	if (ws_win_create(c, f, 0, &win)) return 1;
	for (int y = 0; y < (int)f.h; y++) for (int x = 0; x < (int)f.w; x++) {
		uint8_t *p = win.px->px + (size_t)y * win.px->stride + (size_t)x * 4; int grid = (x % 40 == 0) || (y % 40 == 0);
		int bar = y < 28;
		p[0] = grid ? 255 : (bar ? 70 : 230); p[1] = grid ? 255 : (bar ? 70 : 115); p[2] = grid ? 255 : (bar ? 255 : 30); p[3] = 255;       /* BGRA */
	}
	ws_win_order(c, &win, 1, 0); ws_win_flush(c, &win);
	usleep(300000);
	double wr[4] = { f.x, sh - (f.y + f.h), f.w, f.h };                         /* y up */
	double icon[4] = { sw / 2 + 100, 6, 58, 58 };                               /* a Dock tile at the bottom, y up */
	int frames = 30;
	for (int i = 0; i <= frames; i++) {
		float mesh[GENIE_MAX_FLOATS]; int cols, rows; float done;
		int n = genie_mesh(wr, icon, (float)i / frames, 1, mesh, &cols, &rows, &done);
		if (n) ws_win_warp(c, &win, cols, rows, mesh);
		if (argc > 1 && i % 5 == 0) { char nm[256]; snprintf(nm, sizeof nm, "%s-%d.ppm", argv[1], i); ws_screenshot(c, nm); }
		usleep(16000);
	}
	ws_win_warp(c, &win, 0, 0, NULL);
	ws_disconnect(c);
	return 0;
}
