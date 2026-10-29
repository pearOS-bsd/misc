/* wsspace shutdown | get | active SPACE | window ID SPACE: full-screen spaces through the wsd private extension (tests) */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL); if (!c || argc < 2) { fprintf(stderr, "usage: wsspace get | active SPACE | window ID SPACE\n"); return 1; }
	if (!strcmp(argv[1], "get")) { uint32_t s = 0; ws_get_active_space(c, &s); printf("active space %u\n", s); }
	else if (!strcmp(argv[1], "night") && argc > 2) printf("rc %d\n", ws_set_night_shift(c, atoi(argv[2])));
	else if (!strcmp(argv[1], "shutdown")) printf("rc %d\n", ws_set_shutdown_splash(c, 1));
	else if (!strcmp(argv[1], "active") && argc > 2) ws_set_active_space(c, (uint32_t)atoi(argv[2]));
	else if (!strcmp(argv[1], "window") && argc > 3) { ws_win w = { (ws_wid)atoi(argv[2]), NULL }; printf("rc %d\n", ws_win_set_space(c, &w, (uint32_t)atoi(argv[3]))); }
	ws_disconnect(c); return 0;
}
