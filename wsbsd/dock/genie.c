#include "genie.h"
#include <math.h>
#include <string.h>

#define PI 3.141592653589793
#define PIF 3.1415927410125732                     /* the float value of pi that the original multiplies with in some places */
static int g_depth;                                 /* the recursion counter of the original (a global that is reset for every mesh) */

/* the easing of an offset: 0.5 - 0.5 cos(pi (pos - base) / span) */
static double ease(double pos, double base, double span) { return -0.5 * cos(((pos - base) * PIF) / span) + 0.5; }

/* the points between a and b where the linear interpolation of the profile would be wrong by 0.6 px or more, in order from a to b: written as (pos, off1, off2) triples at buf + *n */
static void subdivide(double a, double b, double base, double k1, double k2, float *buf, int *n, int span)
{
	double dspan = (double)span;
	if (g_depth >= 0x40) { g_depth++; return; }
	double eb = ease(b, base, dspan);
	g_depth++;
	do {
		if (fabs(b - a) < 8.0) return;
		double mid = (a + b) * 0.5, ea = ease(a, base, dspan), em = ease(mid, base, dspan);
		float f1 = (float)(k1 * em), f2 = (float)(k2 * em);
		if (fabs(b - a) < 128.0 && fabs(((float)(k1 * eb) + (float)(k1 * ea)) * 0.5 - f1) < 0.6 && fabs(((float)(k2 * eb) + (float)(k2 * ea)) * 0.5 - f2) < 0.6) return;
		subdivide(a, mid, base, k1, k2, buf, n, span);
		if (*n + 3 > 0x4af) return;
		buf[*n] = (float)mid; buf[*n + 1] = f1; buf[*n + 2] = f2; *n += 3;
		a = mid;
	} while (g_depth++ < 0x40);
}

int genie_mesh(const double win[4], const double icon[4], float progress, int dir, float *mesh, int *cols, int *rows, float *done)
{
	double wx = win[0], wy = win[1], ww = win[2], wh = win[3];
	double dx = (float)icon[0], dy = (float)icon[1], dw = (float)icon[2], dh = (float)icon[3];       /* the tile rect arrives as floats */
	double d14 = 0, d34 = 0, d28 = 0, d33 = 0, d24 = 0, d27 = 0, d30 = 0, d29 = 0, d32 = 0;
	switch (dir) {
	case 1:
		d14 = -wh; d32 = dy + dh; d30 = wy + wh; d28 = dx - wx; d33 = (dx + dw) - (wx + ww);
		if (0.0 <= d32 - wy) d34 = d32 - wy;
		d24 = -dh; d27 = dy; d29 = d14; if (d34 <= 0.0) d29 = d32 - d30;
		break;
	case 2:
		d27 = dy + dh; d28 = dx - wx; d33 = (dx + dw) - (wx + ww);
		d14 = wy - (dy + dh); if (d14 <= 0.0) d34 = d14;
		d24 = dh; d30 = wy; d29 = wh; d14 = wh; d32 = dy; if (0.0 <= d34) d29 = dy - wy;
		break;
	case 3:
		d28 = dy - wy; d33 = (dy + dh) - (wy + wh);
		d14 = dx - (wx + ww); if (d14 <= 0.0) d34 = d14;
		d24 = dw; d27 = dx + dw; d30 = wx; d29 = ww; d14 = ww; d32 = dx; if (0.0 <= d34) d29 = dx - wx;
		break;
	case 4:
		d14 = -ww; d32 = dx + dw; d30 = wx + ww; d28 = dy - wy; d33 = (dy + dh) - (wy + wh);
		if (0.0 <= d32 - wx) d34 = d32 - wx;
		d24 = -dw; d27 = dx; d29 = d14; if (d34 <= 0.0) d29 = d32 - d30;
		break;
	default: *cols = *rows = 0; *done = 1; return 0;
	}
	/* the two phases: the length of the first (the sides moving in) and of the second (travelling to the tile), in "pixels" of the original's easing parameter */
	double t = (fabs(d28) + fabs(d33)) * 0.125, u = fabs(d34 + d34); if (u <= t) u = t;
	double A = (double)(int)log(fabs(u) * 0.5 + 1.0) * 50.0;
	double travel = fabs(d29); if (travel < 1e-9) { *cols = *rows = 0; *done = 1; return 0; }
	double B = (double)(int)log(travel * 0.5 + 1.0) * 50.0;
	double a2 = acos(((fabs(d29 - d14) * B) / travel) / B * -2.0 + 1.0);
	double lead = B * (a2 / PI);
	double gap = A - lead;
	if (A <= lead) { gap = 0.0; A = lead; }
	double q = (B + gap) * (double)progress;
	double qa = q <= A ? q : A; if (!(0.0 <= q)) qa = 0.0;                       /* the first phase: q clamped to 0 ... A */
	double q2 = q - gap;
	double qb = q2 <= B ? q2 : B; if (!(0.0 <= q2)) qb = 0.0;                    /* the second phase: q - gap clamped to 0 ... B */
	double e1 = A > 0 ? cos((qa / A) * PI) * -0.5 + 0.5 : 1.0, e2 = B > 0 ? cos((qb / B) * PI) * -0.5 + 0.5 : 1.0;
	d28 *= e1; d33 *= e1;
	double d31 = d29 * e2;
	d30 = d30 + d34 * e1;
	d34 = d30 + d31;
	double d17 = d14 + d34, d13 = d17, d22 = d17;
	if (d17 < d32) d13 = d32;
	if (d32 < d17) d22 = d32;
	if (((unsigned)dir & ~1u) == 2) d13 = d22;
	double far_end = d17; if (0.0 < e2) far_end = d13;                         /* d32 of the original after the clamp */
	g_depth = 0;
	int span = (int)(d29 + 0.5);
	float prof[1200 * 3 + 8]; int np = 0;
	double e0 = ((d34 - d30) * PIF) / (double)span; e0 = cos(e0) * -0.5 + 0.5;
	prof[0] = (float)d34; prof[1] = (float)(d28 * e0); prof[2] = (float)(d33 * e0); np = 3;
	subdivide(d34, far_end, d30, d28, d33, prof, &np, span);
	double ee = ((far_end - d30) * PIF) / (double)span; ee = cos(ee) * -0.5 + 0.5;
	prof[np] = (float)far_end; prof[np + 1] = (float)(d28 * ee); prof[np + 2] = (float)(d33 * ee); np += 3;
	double a31 = fabs(d31);
	if (fabs(d29 - d14) < a31) {
		double v = d17;
		if (((unsigned)dir & ~1u) == 2) { if (d27 < v) v = d27; } else if (v < d27) v = d27;
		prof[np] = (float)v; prof[np + 1] = (float)d28; prof[np + 2] = (float)d33; np += 3;
	}
	int n = np / 3;
	float *m = mesh; int w = 0, h = 0;
	if (n > 2) {
		float p0 = prof[0], pl = prof[(n - 1) * 3];
		if (dir == 1) {
			for (int i = 0; i < n; i++) {
				int j = n - 1 - i; float pj = prof[j * 3], sy = (float)(((double)pj - (double)pl) * (wh / ((double)p0 - (double)pl)));
				m[8 * i + 0] = 0; m[8 * i + 1] = sy; m[8 * i + 2] = (float)(wx + prof[j * 3 + 1]); m[8 * i + 3] = pj;
				m[8 * i + 4] = (float)ww; m[8 * i + 5] = sy; m[8 * i + 6] = (float)(wx + ww + prof[j * 3 + 2]); m[8 * i + 7] = pj;
			}
			w = 2; h = n;
		} else if (dir == 2) {
			for (int i = 0; i < n; i++) {
				float pj = prof[i * 3], sy = (float)(((double)pj - (double)p0) * (wh / ((double)pl - (double)p0)));
				m[8 * i + 0] = 0; m[8 * i + 1] = sy; m[8 * i + 2] = (float)(wx + prof[i * 3 + 1]); m[8 * i + 3] = pj;
				m[8 * i + 4] = (float)ww; m[8 * i + 5] = sy; m[8 * i + 6] = (float)(wx + ww + prof[i * 3 + 2]); m[8 * i + 7] = pj;
			}
			w = 2; h = n;
		} else if (dir == 3) {
			for (int i = 0; i < n; i++) {
				float pj = prof[i * 3], sx = (float)(((double)pj - (double)p0) * (ww / ((double)pl - (double)p0)));
				m[4 * i + 0] = sx; m[4 * i + 1] = 0; m[4 * i + 2] = pj; m[4 * i + 3] = (float)(wy + prof[i * 3 + 1]);
				m[4 * (n + i) + 0] = sx; m[4 * (n + i) + 1] = (float)wh; m[4 * (n + i) + 2] = pj; m[4 * (n + i) + 3] = (float)(wy + wh + prof[i * 3 + 2]);
			}
			w = n; h = 2;
		} else {
			for (int i = 0; i < n; i++) {
				int j = n - 1 - i; float pj = prof[j * 3], sx = (float)(((double)pj - (double)pl) * (ww / ((double)p0 - (double)pl)));
				m[4 * i + 0] = sx; m[4 * i + 1] = 0; m[4 * i + 2] = pj; m[4 * i + 3] = (float)(wy + prof[j * 3 + 1]);
				m[4 * (n + i) + 0] = sx; m[4 * (n + i) + 1] = (float)wh; m[4 * (n + i) + 2] = pj; m[4 * (n + i) + 3] = (float)(wy + wh + prof[j * 3 + 2]);
			}
			w = n; h = 2;
		}
	}
	*cols = w; *rows = h;
	double rest = travel - fabs(d31);                                           /* how much of the travel is left */
	if (fabs(d14) <= fabs(d24)) *done = rest == 0.0 ? 1.0f : 0.0f;
	else { double span2 = fabs(d14) - fabs(d24); *done = rest < span2 ? (float)(1.0 - rest / span2) : 0.0f; }
	return w * h * 4;
}
