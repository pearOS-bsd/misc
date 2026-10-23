/* wskey code...: presses and releases each CGKeyCode in turn (through the wsd test injection); +code only presses (a modifier held: 55 command, 56 shift, 58 option, 59 control), -code only releases:  wskey +55 2 -55  is command-D */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL);
	if (!c || argc < 2) { fprintf(stderr, "usage: wskey code...\n"); return 1; }
	for (int i = 1; i < argc; i++) {
		const char *a = argv[i]; const char *nm = a[0] == '+' || a[0] == '-' ? a + 1 : a; int k = atoi(nm);
		/* modifier names (the compositor keeps the modifier state from the evdev keys; an injected CGKeyCode does not change it): +cmd -cmd, +shift, +opt, +ctrl */
		{ int m = !strcmp(nm, "cmd") ? 0x100000 : !strcmp(nm, "shift") ? 0x20000 : !strcmp(nm, "opt") ? 0x80000 : !strcmp(nm, "ctrl") ? 0x40000 : 0; if (m) { ws_inject_key(c, 0x40000000 | m, a[0] == '+'); usleep(60000); continue; } }
		if (a[0] == '+') { ws_inject_key(c, k, 1); usleep(60000); continue; }
		if (a[0] == '-') { ws_inject_key(c, k, 0); usleep(60000); continue; }
		ws_inject_key(c, k, 1); usleep(60000);
		ws_inject_key(c, k, 0); usleep(60000);
	}
	ws_disconnect(c);
	return 0;
}
