/* Matrix interpolation: the 2D (affine) decomposition used by Core Animation (CA::Mat2Impl::mat2_get_unmatrix, mat2_mix, mat2_rotate) and the 3D one. */
#include "CAMatrix.h"
#include <math.h>
#include <string.h>

/* m = {a, b, c, d, tx, ty}: rows (a b) (c d), translation (tx ty) */
typedef struct { double sx, sy, tx, ty, angle, r[4]; } UnMat2;

static void mat2_rotate(double *m, double angle)
{
	double s = sin(angle), c = cos(angle);
	if (fabs(s) < 1e-7) { c = copysign(1.0, c); s = 0; }
	else if (fabs(c) < 1e-7) { s = copysign(1.0, s); c = 0; }
	double r0x = m[0], r0y = m[1], r1x = m[2], r1y = m[3];
	m[0] = r0x * c + r1x * s;   m[1] = r0y * c + r1y * s;
	m[2] = r0x * -s + r1x * c;  m[3] = r0y * -s + r1y * c;
}

static void mat2_get_unmatrix(const double *m, UnMat2 *u)
{
	double r0[2] = { m[0], m[1] }, r1[2] = { m[2], m[3] };
	u->tx = m[4]; u->ty = m[5];
	double sx = sqrt(r0[0] * r0[0] + r0[1] * r0[1]), sy = sqrt(r1[0] * r1[0] + r1[1] * r1[1]);
	u->sx = sx; u->sy = sy;
	if (r1[0] * r0[1] > r1[1] * r0[0]) {                    /* negative determinant: one of the scales is negative */
		if (r1[1] > r0[0]) { sx = -sx; u->sx = sx; } else { sy = -sy; u->sy = sy; }
	}
	if (sx != 0) { double k = 1.0 / sx; r0[0] *= k; r0[1] *= k; }
	if (sy != 0) { double k = 1.0 / sy; r1[0] *= k; r1[1] *= k; }
	u->angle = atan2(r0[1], r0[0]);
	if (u->angle != 0) {
		double s = sin(u->angle), c = cos(u->angle);
		u->r[0] = r0[0] * c - r1[0] * s;  u->r[1] = r0[1] * c - r1[1] * s;
		u->r[2] = r0[0] * s + r1[0] * c;  u->r[3] = r0[1] * s + r1[1] * c;
	} else { u->r[0] = r0[0]; u->r[1] = r0[1]; u->r[2] = r1[0]; u->r[3] = r1[1]; }
}

void CAMat2Mix(double *out, const double *a, const double *b, double t)
{
	UnMat2 A, B;
	mat2_get_unmatrix(a, &A); mat2_get_unmatrix(b, &B);
	double sx = A.sx, sy = A.sy;
	if ((A.sx < 0 && B.sy < 0) || (A.sy < 0 && B.sx < 0)) {
		sx = -sx; sy = -sy;
		A.angle += A.angle < 0 ? M_PI : -M_PI;
	}
	double aa = A.angle, ba = B.angle;
	if (aa == 0) aa = 2 * M_PI;
	if (ba == 0) ba = 2 * M_PI;
	if (fabs(aa - ba) > M_PI) { if (aa > ba) aa += -2 * M_PI; else ba += -2 * M_PI; }
	double msx = sx + (B.sx - sx) * t, msy = sy + (B.sy - sy) * t;
	double mtx = A.tx + (B.tx - A.tx) * t, mty = A.ty + (B.ty - A.ty) * t;
	double mr[4]; for (int i = 0; i < 4; i++) mr[i] = A.r[i] + (B.r[i] - A.r[i]) * t;
	double ang = aa + (ba - aa) * t;
	out[0] = mr[0]; out[1] = mr[1]; out[2] = mr[2]; out[3] = mr[3]; out[4] = mtx; out[5] = mty;
	if (ang != 0) mat2_rotate(out, ang);
	if (!(msx == 1 && msy == 1)) { out[0] *= msx; out[1] *= msx; out[2] *= msy; out[3] *= msy; }
}

/* the general (3D) case: until it is decompiled it falls back to a component-wise blend, which agrees at the ends and for translations */
void CAMat4Mix(double *out, const double *a, const double *b, double t)
{
	for (int i = 0; i < 16; i++) out[i] = a[i] == b[i] ? a[i] : a[i] + (b[i] - a[i]) * t;
}
