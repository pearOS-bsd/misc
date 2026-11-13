/* wscarender: shows the CoreAnimation scene of ca.bin (+ ca-ool files) in a window of wsd.  usage: wscarender CADIR [x y [level [w h]]]
 * The decoding and painting live in src/ca_scene.c (the part that is meant to run inside wsd). */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include "ws_client.h"
#include "ca_scene.h"

int main(int argc, char **argv)
{
	int x = argc > 3 ? atoi(argv[2]) : 0, y = argc > 3 ? atoi(argv[3]) : 0, level = argc > 4 ? atoi(argv[4]) : 0, w = argc > 6 ? atoi(argv[5]) : 1280, h = argc > 6 ? atoi(argv[6]) : 800;
	char path[512]; off_t last = -1;
	ws_win win; ws_conn *c;

	if (argc < 2) { fprintf(stderr, "usage: wscarender CADIR [x y [level [w h]]]\n"); return 1; }
	ca_set_dir(argv[1]); snprintf(path, sizeof path, "%s/ca.bin", argv[1]);
	if ((c = ws_connect(NULL)) == NULL) { fprintf(stderr, "wscarender: cannot connect to wsd\n"); return 1; }
	if (ws_win_create(c, (ws_rect){ x, y, w, h }, level, &win)) { fprintf(stderr, "wscarender: cannot create the window\n"); return 1; }
	ws_win_order(c, &win, WS_ABOVE, 0);
	for (;;) {
		struct stat st;
		if (stat(path, &st) == 0 && st.st_size != last) {
			if (ca_load_file(path) == 0) {
				ca_paint(win.px->px, win.px->w, win.px->h, win.px->stride); ws_win_flush(c, &win);
				fprintf(stderr, "wscarender: %ld bytes, %d layers, %d images, %d records resynchronised\n", (long)st.st_size, ca_nlayers(), ca_nimages(), ca_resynced());
				last = st.st_size;
			}
		}
		usleep(500000);
	}
}
