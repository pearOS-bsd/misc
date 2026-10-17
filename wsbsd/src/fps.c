/* System-wide frame rate: every frame the compositor presents (to a VNC viewer or a KMS display) is counted, the rate is the frames of the last second. An optional overlay
 * draws it in the top right corner of the screen with a 5x7 bitmap font. */
#include <stdio.h>
#include <string.h>
#include <time.h>
#include "ws.h"

static struct { double t0, last_report; unsigned frames; double rate, compose_ms, compose_acc; unsigned long total; } st;

static double now_s(void) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); return t.tv_sec + t.tv_nsec / 1e9; }

void ws_fps_frame(double compose_ms)
{
	double t = now_s();
	if (st.t0 == 0) st.t0 = t;
	st.frames++; st.total++; st.compose_acc += compose_ms;
	if (t - st.t0 >= 1.0) {
		st.rate = st.frames / (t - st.t0); st.compose_ms = st.compose_acc / st.frames;
		st.frames = 0; st.compose_acc = 0; st.t0 = t;
	}
}
double ws_fps_rate(void)
{
	/* nothing was presented for a while: the rate is 0, not the last busy second */
	if (st.t0 != 0 && now_s() - st.t0 > 2.0) return 0;
	return st.rate;
}
double ws_fps_compose_ms(void) { return st.compose_ms; }
unsigned long ws_fps_total(void) { return st.total; }

/* 5x7 glyphs: digits, '.', ' ', F, P, S, m, s, / (rows of 5 bits, top first) */
static const struct { char c; unsigned char r[7]; } font[] = {
	{ '0', { 0x0E, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0E } }, { '1', { 0x04, 0x0C, 0x04, 0x04, 0x04, 0x04, 0x0E } },
	{ '2', { 0x0E, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1F } }, { '3', { 0x1F, 0x02, 0x04, 0x02, 0x01, 0x11, 0x0E } },
	{ '4', { 0x02, 0x06, 0x0A, 0x12, 0x1F, 0x02, 0x02 } }, { '5', { 0x1F, 0x10, 0x1E, 0x01, 0x01, 0x11, 0x0E } },
	{ '6', { 0x06, 0x08, 0x10, 0x1E, 0x11, 0x11, 0x0E } }, { '7', { 0x1F, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08 } },
	{ '8', { 0x0E, 0x11, 0x11, 0x0E, 0x11, 0x11, 0x0E } }, { '9', { 0x0E, 0x11, 0x11, 0x0F, 0x01, 0x02, 0x0C } },
	{ '.', { 0, 0, 0, 0, 0, 0x0C, 0x0C } }, { 'F', { 0x1F, 0x10, 0x10, 0x1E, 0x10, 0x10, 0x10 } },
	{ 'P', { 0x1E, 0x11, 0x11, 0x1E, 0x10, 0x10, 0x10 } }, { 'S', { 0x0F, 0x10, 0x10, 0x0E, 0x01, 0x01, 0x1E } },
	{ 'm', { 0, 0, 0x1A, 0x15, 0x15, 0x15, 0x15 } }, { 's', { 0, 0, 0x0F, 0x10, 0x0E, 0x01, 0x1E } },
	{ ' ', { 0, 0, 0, 0, 0, 0, 0 } }, { '|', { 0x04, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04 } },
};

static void put(ws_surface *img, int x, int y, uint8_t b, uint8_t g, uint8_t r)
{
	if (x < 0 || y < 0 || x >= img->w || y >= img->h) return;
	uint8_t *d = img->px + (size_t)y * img->stride + (size_t)x * 4; d[0] = b; d[1] = g; d[2] = r; d[3] = 255;
}

int ws_draw_text_small(ws_surface *img, int x, int y, const char *s, int scale)
{
	for (; *s; s++) {
		const unsigned char *rows = NULL;
		for (size_t i = 0; i < sizeof font / sizeof *font; i++) if (font[i].c == *s) { rows = font[i].r; break; }
		if (rows) for (int ry = 0; ry < 7; ry++) for (int rx = 0; rx < 5; rx++) if (rows[ry] & (0x10 >> rx))
			for (int sy = 0; sy < scale; sy++) for (int sx = 0; sx < scale; sx++) put(img, x + rx * scale + sx, y + ry * scale + sy, 255, 255, 255);
		x += 6 * scale;
	}
	return x;
}

void ws_draw_fps(ws_surface *img)
{
	char text[48];
	snprintf(text, sizeof text, "%.0f FPS | %.1f ms", ws_fps_rate(), ws_fps_compose_ms());
	int scale = 2, w = (int)strlen(text) * 6 * scale + 8, h = 7 * scale + 8, x0 = img->w - w - 6, y0 = 34;     /* below the menu bar */
	for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
		uint8_t *d = img->px + (size_t)(y0 + y) * img->stride + (size_t)(x0 + x) * 4;
		if (y0 + y >= img->h || x0 + x < 0) continue;
		d[0] = d[0] / 4; d[1] = d[1] / 4; d[2] = d[2] / 4; d[3] = 255;                                       /* darken what is behind */
	}
	ws_draw_text_small(img, x0 + 4, y0 + 4, text, scale);
}
