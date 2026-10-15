/* wskey code...: presses and releases each CGKeyCode in turn (through the wsd test injection) */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL);
	if (!c || argc < 2) { fprintf(stderr, "usage: wskey code...\n"); return 1; }
	for (int i = 1; i < argc; i++) {
		int k = atoi(argv[i]);
		ws_inject_key(c, k, 1); usleep(60000);
		ws_inject_key(c, k, 0); usleep(60000);
	}
	ws_disconnect(c);
	return 0;
}
