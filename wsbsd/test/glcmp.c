/* glcmp: composes the same scene with the software and the GL compositor and compares the pixels (colour order, completeness, repeatability). */
#include "ws.h"
#include "ws_gl.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
int main(void)
{
	int W = 1280, H = 800;
	ws_server *s = ws_server_new(W, H);
	for (int i = 0; i < 4; i++) {
		ws_wid id = ws_create_window(s, (ws_rect){ 100 + 150 * i, 80 + 60 * i, 400, 300 });
		ws_surface *b = ws_window_backing(s, id);
		float c[4][3] = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 }, { 1, 1, 0 } };
		if (b) ws_fill(b, (ws_rect){ 0, 0, 400, 300 }, c[i][0], c[i][1], c[i][2], 1.0f);
		ws_order_window(s, id, WS_ABOVE, 0);
	}
	ws_surface *A = ws_surface_new(W, H), *B = ws_surface_new(W, H);
	ws_compose_scene(s, A);
	gl_compositor *g = glc_create("/dev/dri/card0", W, H);
	if (!g) { printf("no GL\n"); return 1; }
	printf("%s\n", glc_describe(g));
	for (int pass = 0; pass < 5; pass++) {
		memset(B->px, 0x77, (size_t)B->stride * H);
		int r1 = compositor_render_frame(g, s), r2 = glc_read_pixels(g, B);
		long bad = 0, swapped = 0, junk = 0;
		for (int y = 0; y < H; y++) for (int x = 0; x < W; x++) {
			const uint8_t *a = A->px + (size_t)y * A->stride + x * 4, *b = B->px + (size_t)y * B->stride + x * 4;
			if (abs(a[0]-b[0]) > 3 || abs(a[1]-b[1]) > 3 || abs(a[2]-b[2]) > 3) {
				bad++; if (abs(a[0]-b[2]) <= 3 && abs(a[2]-b[0]) <= 3) swapped++; if (b[0] == 0x77 && b[1] == 0x77) junk++; }
		}
		printf("pass %d: render=%d read=%d mismatching px %ld of %d (R/B swapped %ld, untouched %ld)\n", pass, r1, r2, bad, W * H, swapped, junk);
		if (pass == 0) { int x = 300, y = 200; const uint8_t *a = A->px + y*A->stride + x*4, *b = B->px + y*B->stride + x*4;
			printf("sample (%d,%d): sw %d,%d,%d,%d  gl %d,%d,%d,%d\n", x, y, a[0],a[1],a[2],a[3], b[0],b[1],b[2],b[3]); }
	}
	return 0;
}
