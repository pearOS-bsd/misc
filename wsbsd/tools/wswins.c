/* wswins: lists the windows of a running wsd (id, owner, level, alpha, bounds), front to back; wswins ID out.ppm also saves what the compositor holds for one window. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ws_client.h"
int main(int argc, char **argv)
{
	ws_conn *c = ws_connect(NULL); if (!c) { fprintf(stderr, "wswins: cannot connect\n"); return 1; }
	uint32_t ids[256]; int total = 0;
	if (ws_win_list(c, 0, 0, ids, 256, &total) != 0) { fprintf(stderr, "wswins: list failed\n"); return 1; }
	for (int i = 0; i < total && i < 256; i++) {
		ws_win w = { .id = ids[i], .px = NULL }; int lv = 0, owner = 0, rights = 0; float al = 0; ws_rect r = { 0, 0, 0, 0 };
		ws_win_get_level(c, &w, &lv); ws_win_get_alpha(c, &w, &al); ws_win_get_bounds(c, &w, &r); ws_win_get_owner(c, &w, &owner, &rights);
		printf("window %u owner %d level %d alpha %.2f bounds %d,%d %dx%d\n", ids[i], owner, lv, al, r.x, r.y, r.w, r.h);
	}
	if (argc > 1 && !strcmp(argv[1], "probe")) {                                    /* ask for each id one by one: a window the list does not show may still exist */
		for (int id = 1; id <= 24; id++) { ws_win w = { .id = (ws_wid)id, .px = NULL }; ws_rect r; int lv; if (ws_win_get_bounds(c, &w, &r) == 0) { ws_win_get_level(c, &w, &lv); printf("probe %d: bounds %d,%d %dx%d level %d\n", id, r.x, r.y, r.w, r.h, lv); } }
		return 0;
	}
	if (argc > 2) {
		ws_surface *s = ws_capture(c, (ws_rect){ 0, 0, 0, 0 }, (uint32_t)atoi(argv[1]), 0);
		if (!s) { fprintf(stderr, "wswins: capture failed\n"); return 1; }
		FILE *f = fopen(argv[2], "wb"); fprintf(f, "P6\n%d %d\n255\n", s->w, s->h);
		for (int y = 0; y < s->h; y++) for (int x = 0; x < s->w; x++) { unsigned char *p = s->px + (size_t)y * s->stride + (size_t)x * 4; fputc(p[2], f); fputc(p[1], f); fputc(p[0], f); }
		fclose(f); printf("saved %dx%d\n", s->w, s->h);
	}
	return 0;
}
