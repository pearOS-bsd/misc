#include "dock_layout.h"
#include <math.h>

#define PAD 7.75                        /* between the bar's edge and the first / last tile */

static double pitch(const DockMetrics *m) { return m->tilesize + 4.0; }
static double sep_width(const DockMetrics *m) { return pitch(m) * (28.0 / 62.0); }
static double base_width(const DockMetrics *m, int kind) { return kind == DOCK_SEPARATOR ? sep_width(m) : kind == DOCK_SMALLSPACER ? pitch(m) * 0.5 : pitch(m); }

/* the size factor of a tile whose centre is d points from the pointer, fitted to the real Dock (AX frames of every tile with the pointer at 9 places along a bar of tilesize 58, largesize 99: the tile box 62 grows to 102 at the pointer; rms 0.010 of the factor, the box is rounded to whole points): 1 + peak * (0.5 (1 + cos(pi d / R)))^0.40, R = 4.534 tile sizes (263 pt), peak = (largesize + 3) / (tilesize + 4) - 1 (the box, art + 4) */
double dock_magnify_factor(const DockMetrics *m, double d)
{
	double R = 4.534 * m->tilesize, peak = ((double)m->largesize + 3.0) / (m->tilesize + 4.0) - 1.0;
	if (d >= R) return 1.0;
	return 1.0 + peak * pow(0.5 * (1.0 + cos(3.14159265358979 * d / R)), 0.40);
}

static void place(const DockMetrics *m, const DockItem *items, int n, const double *scale, DockSlot *slots, double *total)
{
	double x = 0;
	for (int i = 0; i < n; i++) {
		double base = base_width(m, items[i].kind), s = DOCK_IS_GAP(items[i].kind) ? 1.0 : scale[i];
		slots[i].x = x; slots[i].w = base * s; slots[i].scale = s; slots[i].cx = x + slots[i].w * 0.5;
		slots[i].art = (DOCK_IS_GAP(items[i].kind) ? 0 : (double)(int)(m->tilesize * 0.81 + 0.5)) * s;
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
				double target = DOCK_IS_GAP(items[i].kind) ? 1.0 : dock_magnify_factor(m, fabs(slots[i].cx + left - cursor_x));
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
