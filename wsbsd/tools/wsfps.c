/* wsfps [seconds]: prints the compositor's system-wide frame rate (frames presented per second, compose time per frame) once a second */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL);
	int n = argc > 1 ? atoi(argv[1]) : 1;
	if (!c) { fprintf(stderr, "wsfps: cannot connect\n"); return 1; }
	for (int i = 0; i < n; i++) {
		double fps, ms; unsigned long total;
		if (ws_fps(c, &fps, &ms, &total)) { fprintf(stderr, "wsfps: request failed\n"); return 1; }
		printf("%.1f FPS, %.2f ms per frame, %lu frames\n", fps, ms, total);
		if (i + 1 < n) sleep(1);
	}
	return 0;
}
