/* wsclick x y [buttons]: moves the pointer to (x,y), presses and releases the left button (through the wsd test injection) */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL);
	if (!c || argc < 3) { fprintf(stderr, "usage: wsclick x y [buttons: 1 left, 2 right]\n"); return 1; }
	int x = atoi(argv[1]), y = atoi(argv[2]), b = argc > 3 ? atoi(argv[3]) : 1;
	if (argc > 3 && argv[3][0] == 's') { ws_inject_mouse(c, x, y, 0); usleep(50000); ws_inject_scroll(c, x, y, 0, atoi(argv[3] + 1)); ws_disconnect(c); return 0; }          /* wsclick x y sN: the wheel by N points */
	ws_inject_mouse(c, x, y, 0); usleep(100000);
	ws_inject_mouse(c, x, y, b); usleep(100000);
	if (argc > 4) { ws_disconnect(c); return 0; }                              /* a 4th argument: leave the button pressed */
	ws_inject_mouse(c, x, y, 0); usleep(100000);
	ws_disconnect(c);
	return 0;
}
