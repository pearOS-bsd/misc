/* wsdrag x1 y1 x2 y2: presses the left button at (x1,y1), moves to (x2,y2) in steps and releases (through the wsd test injection) */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL);
	if (!c || argc < 5) { fprintf(stderr, "usage: wsdrag x1 y1 x2 y2\n"); return 1; }
	int x1 = atoi(argv[1]), y1 = atoi(argv[2]), x2 = atoi(argv[3]), y2 = atoi(argv[4]);
	ws_inject_mouse(c, x1, y1, 0); usleep(100000);
	ws_inject_mouse(c, x1, y1, 1); usleep(100000);
	for (int i = 1; i <= 10; i++) { ws_inject_mouse(c, x1 + (x2 - x1) * i / 10, y1 + (y2 - y1) * i / 10, 1); usleep(60000); }
	ws_inject_mouse(c, x2, y2, 0); usleep(100000);
	ws_disconnect(c);
	return 0;
}
