/* wsclick x y: moves the pointer to (x,y), presses and releases the left button (through the wsd test injection) */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL);
	if (!c || argc < 3) { fprintf(stderr, "usage: wsclick x y\n"); return 1; }
	int x = atoi(argv[1]), y = atoi(argv[2]);
	ws_inject_mouse(c, x, y, 0); usleep(100000);
	ws_inject_mouse(c, x, y, 1); usleep(100000);
	ws_inject_mouse(c, x, y, 0); usleep(100000);
	ws_disconnect(c);
	return 0;
}
