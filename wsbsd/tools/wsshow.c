/* wsshow: shows a PPM (P6) file in a window and reloads it when it changes.  usage: wsshow file.ppm [x y [level]]
 * Used by tools/ca (the CoreAnimation scene of a Dock drawn to a file) to put that picture on the screen. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include "ws_client.h"

static uint8_t *load(const char *path, int *w, int *h)
{
	FILE *f = fopen(path, "rb");
	int mx;
	uint8_t *d;

	if (!f) return NULL;
	if (fscanf(f, "P6 %d %d %d", w, h, &mx) != 3 || mx != 255) { fclose(f); return NULL; }
	fgetc(f);
	d = malloc((size_t)*w * *h * 3);
	if (!d || fread(d, 3, (size_t)*w * *h, f) != (size_t)*w * *h) { free(d); fclose(f); return NULL; }
	fclose(f);
	return d;
}

int main(int argc, char **argv)
{
	int w, h, x = argc > 3 ? atoi(argv[2]) : 0, y = argc > 3 ? atoi(argv[3]) : 0, level = argc > 4 ? atoi(argv[4]) : 0;
	time_t last = 0;
	ws_win win;
	ws_conn *c;
	uint8_t *d;

	if (argc < 2) { fprintf(stderr, "usage: wsshow file.ppm [x y [level]]\n"); return 1; }
	if ((d = load(argv[1], &w, &h)) == NULL) { fprintf(stderr, "wsshow: cannot read %s\n", argv[1]); return 1; }
	if ((c = ws_connect(NULL)) == NULL) { fprintf(stderr, "wsshow: cannot connect to wsd\n"); return 1; }
	if (ws_win_create(c, (ws_rect){ x, y, w, h }, level, &win)) { fprintf(stderr, "wsshow: cannot create the window\n"); return 1; }
	ws_win_order(c, &win, WS_ABOVE, 0);
	for (;;) {
		struct stat st;

		if (stat(argv[1], &st) == 0 && st.st_mtime != last) {
			uint8_t *n = load(argv[1], &w, &h);

			if (n && w == win.px->w && h == win.px->h) {
				for (int j = 0; j < h; j++) {
					uint8_t *row = win.px->px + (size_t)j * win.px->stride;
					for (int i = 0; i < w; i++) {
						row[i * 4 + 0] = n[(j * w + i) * 3 + 2]; row[i * 4 + 1] = n[(j * w + i) * 3 + 1]; row[i * 4 + 2] = n[(j * w + i) * 3 + 0]; row[i * 4 + 3] = 255;
					}
				}
				ws_win_flush(c, &win);
				last = st.st_mtime;
			}
			free(n);
		}
		usleep(300000);
	}
}
