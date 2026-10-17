/* wscursor shape: sets the pointer to a standard shape (0 arrow, 1 I-beam, 2 hand, 3 crosshair, 4 left-right, 5 up-down, 6 NW-SE, 7 NE-SW, 8 open hand, 9 closed hand, 10 move) */
#include <stdio.h>
#include <stdlib.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL);
	if (!c || argc < 2) { fprintf(stderr, "usage: wscursor shape\n"); return 1; }
	int r = ws_cursor_set_shape(c, atoi(argv[1]));
	printf("%d\n", r);
	return r ? 1 : 0;
}
