/* wsgrey L [seconds]: a window over the whole screen in a uniform grey L (0..255), under the Dock's level, for measuring a material over a known backdrop */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL); int w, h, l = argc > 1 ? atoi(argv[1]) : 128, secs = argc > 2 ? atoi(argv[2]) : 30; ws_win win;
	if (!c || ws_conn_screen(c, &w, &h) || ws_win_create(c, (ws_rect){ 0, 0, w, h }, 0, &win)) { fprintf(stderr, "wsgrey: no window\n"); return 1; }
	for (int y = 0; y < win.px->h; y++) for (int x = 0; x < win.px->w; x++) { uint8_t *p = win.px->px + (size_t)y * win.px->stride + (size_t)x * 4; p[0] = p[1] = p[2] = (uint8_t)l; p[3] = 255; }
	ws_win_order(c, &win, 1, 0); ws_win_flush(c, &win); sleep(secs); return 0;
}
