/* wskey code...: presses and releases each CGKeyCode in turn (through the wsd test injection); +code only presses (a modifier held: 55 command, 56 shift, 58 option, 59 control), -code only releases:  wskey +55 2 -55  is command-D */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL);
	if (!c || argc < 2) { fprintf(stderr, "usage: wskey code...\n"); return 1; }
	for (int i = 1; i < argc; i++) {
		const char *a = argv[i]; int k = atoi(a[0] == '+' || a[0] == '-' ? a + 1 : a);
		if (a[0] == '+') { ws_inject_key(c, k, 1); usleep(60000); continue; }
		if (a[0] == '-') { ws_inject_key(c, k, 0); usleep(60000); continue; }
		ws_inject_key(c, k, 1); usleep(60000);
		ws_inject_key(c, k, 0); usleep(60000);
	}
	ws_disconnect(c);
	return 0;
}
