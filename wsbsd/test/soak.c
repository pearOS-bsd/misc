/* soak: connects, creates windows with shadows / blur / tracking regions / surfaces / properties, flushes, destroys and disconnects, many times; the server's memory must not grow.
 * usage: soak <iterations> ; WS_SOCKET selects the server; prints the server's resident size (pid from argv[2]) before and after */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "ws_client.h"

static long rss_kb(int pid)
{
	char cmd[64], line[64]; snprintf(cmd, sizeof cmd, "ps -o rss= -p %d", pid);
	FILE *f = popen(cmd, "r"); long v = -1; if (f) { if (fgets(line, sizeof line, f)) v = atol(line); pclose(f); } return v;
}

int main(int argc, char **argv)
{
	int n = argc > 1 ? atoi(argv[1]) : 2000, pid = argc > 2 ? atoi(argv[2]) : 0;
	long before = pid ? rss_kb(pid) : -1, mid = -1;
	for (int i = 0; i < n; i++) {
		ws_conn *c = ws_connect(NULL); if (!c) { printf("connect failed at %d\n", i); return 1; }
		ws_win w[4];
		for (int k = 0; k < 4; k++) {
			if (ws_win_create(c, (ws_rect){ 10 * k, 10 * k, 200 + 10 * k, 150 }, k, &w[k])) { printf("create failed\\n"); return 1; }
			ws_win_shadow(c, &w[k], 10, 1); ws_win_order(c, &w[k], 1, 0);
			ws_win_alpha(c, &w[k], 0.9f);
			ws_win_flush(c, &w[k]);
		}
		ws_surface *s = ws_capture(c, (ws_rect){ 0, 0, 64, 64 }, 0, 0); if (s) ws_surface_free(s);
		for (int k = 0; k < 4; k++) ws_win_release(c, &w[k]);
		ws_disconnect(c);
		if (i == n / 4) mid = pid ? rss_kb(pid) : -1;
	}
	long after = pid ? rss_kb(pid) : -1;
	printf("soak: %d iterations, server rss %ld KB -> %ld KB (after a quarter: %ld KB)\n", n, before, after, mid);
	return 0;
}
