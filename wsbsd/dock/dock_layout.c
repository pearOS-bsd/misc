#include "dock_layout.h"
#include <math.h>

#define PAD 7.75                        /* between the bar's edge and the first / last tile */

static double pitch(const DockMetrics *m) { return m->tilesize + 4.0; }
static double sep_width(const DockMetrics *m) { return pitch(m) * (28.0 / 62.0); }

/* the size factor of a tile whose centre is d points from the pointer: a Gaussian bell (3 tile sizes) cut off at 5.2 tile sizes, fitted to the real Dock in the expanded layout */
double dock_magnify_factor(const DockMetrics *m, double d)
{
	double sigma = 3.0 * m->tilesize, R = 5.2 * m->tilesize, peak = (double)m->largesize / m->tilesize - 1.0;
	if (d >= R) return 1.0;
	double e0 = exp(-R * R / (2 * sigma * sigma));                                 /* the bell ends at R: the tiles beyond are not magnified at all */
	return 1.0 + peak * (exp(-d * d / (2 * sigma * sigma)) - e0) / (1.0 - e0);
}

static void place(const DockMetrics *m, const DockItem *items, int n, const double *scale, DockSlot *slots, double *total)
{
	double x = 0;
	for (int i = 0; i < n; i++) {
		double base = items[i].kind == DOCK_SEPARATOR ? sep_width(m) : pitch(m), s = items[i].kind == DOCK_SEPARATOR ? 1.0 : scale[i];
		slots[i].x = x; slots[i].w = base * s; slots[i].scale = s; slots[i].cx = x + slots[i].w * 0.5;
		slots[i].art = (items[i].kind == DOCK_SEPARATOR ? 0 : (double)(int)(m->tilesize * 0.81 + 0.5)) * s;
		x += slots[i].w;
	}
	*total = x;
}

void dock_layout(const DockMetrics *m, const DockItem *items, int n, double cursor_x, DockSlot *slots, DockBar *bar)
{
	double scale[256], total = 0;
	if (n > 256) n = 256;
	for (int i = 0; i < n; i++) scale[i] = 1.0;
	bar->bar_h = m->tilesize + 20.0; bar->bottom_margin = 5.0; bar->art_rest = (double)(int)(m->tilesize * 0.81 + 0.5);
	place(m, items, n, scale, slots, &total);
	double left = (m->screen_w - (total + 2 * PAD)) / 2.0 + PAD;
	double rest_left = left, rest_total = total;
	if (m->magnification && cursor_x >= rest_left - PAD && cursor_x <= rest_left + rest_total + PAD) {
		/* the scale of a tile depends on where the tile is, which depends on the scales: iterate to the layout that agrees with itself (the bar stays centred on the screen) */
		for (int it = 0; it < 200; it++) {
			double moved = 0;
			for (int i = 0; i < n; i++) {
				double target = items[i].kind == DOCK_SEPARATOR ? 1.0 : dock_magnify_factor(m, fabs(slots[i].cx + left - cursor_x));
				double ns = scale[i] + (target - scale[i]) * 0.5; moved += fabs(ns - scale[i]); scale[i] = ns;
			}
			place(m, items, n, scale, slots, &total);
			left = (m->screen_w - (total + 2 * PAD)) / 2.0 + PAD;
			if (moved < 1e-7) break;
		}
	}
	for (int i = 0; i < n; i++) { slots[i].x += left; slots[i].cx += left; }
	bar->bar_x = left - PAD; bar->bar_w = total + 2 * PAD;
}
