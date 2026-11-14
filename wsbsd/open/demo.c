#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "ws_client.h"
int main(void)
{
	ws_win win; ws_conn *c = ws_connect(NULL);
	if (!c) { fprintf(stderr, "cannot connect\n"); return 1; }
	if (ws_win_create(c, (ws_rect){ 200, 150, 420, 300 }, 0, &win)) { fprintf(stderr, "cannot create window\n"); return 1; }
	for (int y = 0; y < win.px->h; y++) { unsigned char *p = (unsigned char *)win.px->px + (size_t)y * win.px->stride; for (int x = 0; x < win.px->w; x++) { p[4*x] = 40; p[4*x+1] = (unsigned char)(200 - y/2); p[4*x+2] = 240; p[4*x+3] = 255; } }
	ws_win_order(c, &win, WS_ABOVE, 0); ws_win_flush(c, &win);
	fprintf(stderr, "open-demo: window shown\n"); sleep(60); return 0;
}
