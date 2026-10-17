/* wsmove x y [x y ...]: moves the pointer (no button) to each point in turn (through the wsd test injection) */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL);
	if (!c || argc < 3) { fprintf(stderr, "usage: wsmove x y [x y ...]\n"); return 1; }
	for (int i = 1; i + 1 < argc; i += 2) { ws_inject_mouse(c, atoi(argv[i]), atoi(argv[i + 1]), 0); usleep(150000); }
	return 0;
}
