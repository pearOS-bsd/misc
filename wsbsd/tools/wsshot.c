/* wsshot: asks the running wsd for a screenshot (PPM) */
#include <stdio.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL);
	if (!c || argc < 2) { fprintf(stderr, "usage: wsshot out.ppm\n"); return 1; }
	int r = ws_screenshot(c, argv[1]);
	ws_disconnect(c);
	return r ? 1 : 0;
}
