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

/* ---- the general (3D) case: perspective, translation, scale, skew and a rotation quaternion, blended part by part (the decomposition of the CSS transforms specification that Core Animation follows) ---- */
typedef struct { double persp[4], trans[3], scale[3], skew[3], quat[4]; } Dec4;
#define M4(m, r, c) (m)[(r) * 4 + (c)]
static void m4_identity(double *m) { memset(m, 0, 16 * sizeof(double)); m[0] = m[5] = m[10] = m[15] = 1; }
static void m4_mul(double *out, const double *a, const double *b)        /* a first, then b (row vectors) */
{
	double t[16];
	for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) { double v = 0; for (int k = 0; k < 4; k++) v += M4(a, i, k) * M4(b, k, j); M4(t, i, j) = v; }
	memcpy(out, t, sizeof t);
}
static double m4_det3(const double *m)        /* the upper left 3x3 */
{
	return M4(m, 0, 0) * (M4(m, 1, 1) * M4(m, 2, 2) - M4(m, 1, 2) * M4(m, 2, 1)) - M4(m, 0, 1) * (M4(m, 1, 0) * M4(m, 2, 2) - M4(m, 1, 2) * M4(m, 2, 0)) + M4(m, 0, 2) * (M4(m, 1, 0) * M4(m, 2, 1) - M4(m, 1, 1) * M4(m, 2, 0));
}
static double m4_det(const double *m)
{
	double d = 0;
	for (int c = 0; c < 4; c++) {
		double sub[9]; int n = 0;
		for (int r = 1; r < 4; r++) for (int cc = 0; cc < 4; cc++) if (cc != c) sub[n++] = M4(m, r, cc);
		double det3 = sub[0] * (sub[4] * sub[8] - sub[5] * sub[7]) - sub[1] * (sub[3] * sub[8] - sub[5] * sub[6]) + sub[2] * (sub[3] * sub[7] - sub[4] * sub[6]);
		d += (c & 1 ? -1 : 1) * M4(m, 0, c) * det3;
	}
	return d;
}
static int m4_invert(double *out, const double *m)
{
	double d = m4_det(m); if (d == 0) return 0;
	double t[16];
	for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) {
		double sub[9]; int n = 0;
		for (int r = 0; r < 4; r++) { if (r == i) continue; for (int c = 0; c < 4; c++) { if (c == j) continue; sub[n++] = M4(m, r, c); } }
		double det3 = sub[0] * (sub[4] * sub[8] - sub[5] * sub[7]) - sub[1] * (sub[3] * sub[8] - sub[5] * sub[6]) + sub[2] * (sub[3] * sub[7] - sub[4] * sub[6]);
		M4(t, j, i) = ((i + j) & 1 ? -1 : 1) * det3 / d;
	}
	memcpy(out, t, sizeof t); return 1;
}
static double dot3(const double *a, const double *b) { return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]; }
static void cross3(double *o, const double *a, const double *b) { o[0] = a[1] * b[2] - a[2] * b[1]; o[1] = a[2] * b[0] - a[0] * b[2]; o[2] = a[0] * b[1] - a[1] * b[0]; }
static void combine3(double *o, const double *a, const double *b, double sa, double sb) { for (int i = 0; i < 3; i++) o[i] = a[i] * sa + b[i] * sb; }

static int dec4(const double *in, Dec4 *d)
{
	double m[16]; memcpy(m, in, sizeof m);
	if (M4(m, 3, 3) == 0) return 0;
	for (int i = 0; i < 16; i++) m[i] /= in[15];
	double pm[16]; memcpy(pm, m, sizeof pm);
	M4(pm, 0, 3) = M4(pm, 1, 3) = M4(pm, 2, 3) = 0; M4(pm, 3, 3) = 1;
	if (m4_det(pm) == 0) return 0;
	if (M4(m, 0, 3) != 0 || M4(m, 1, 3) != 0 || M4(m, 2, 3) != 0) {
		double rhs[4] = { M4(m, 0, 3), M4(m, 1, 3), M4(m, 2, 3), M4(m, 3, 3) }, inv[16], tr[16];
		m4_invert(inv, pm);
		for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) M4(tr, i, j) = M4(inv, j, i);       /* the transpose of the inverse */
		for (int i = 0; i < 4; i++) d->persp[i] = rhs[0] * M4(tr, 0, i) + rhs[1] * M4(tr, 1, i) + rhs[2] * M4(tr, 2, i) + rhs[3] * M4(tr, 3, i);
	} else { d->persp[0] = d->persp[1] = d->persp[2] = 0; d->persp[3] = 1; }
	d->trans[0] = M4(m, 3, 0); d->trans[1] = M4(m, 3, 1); d->trans[2] = M4(m, 3, 2);
	double row[3][3]; for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) row[i][j] = M4(m, i, j);
	d->scale[0] = sqrt(dot3(row[0], row[0])); for (int j = 0; j < 3; j++) row[0][j] /= d->scale[0];
	d->skew[0] = dot3(row[0], row[1]); combine3(row[1], row[1], row[0], 1, -d->skew[0]);
	d->scale[1] = sqrt(dot3(row[1], row[1])); for (int j = 0; j < 3; j++) row[1][j] /= d->scale[1]; d->skew[0] /= d->scale[1];
	d->skew[1] = dot3(row[0], row[2]); combine3(row[2], row[2], row[0], 1, -d->skew[1]);
	d->skew[2] = dot3(row[1], row[2]); combine3(row[2], row[2], row[1], 1, -d->skew[2]);
	d->scale[2] = sqrt(dot3(row[2], row[2])); for (int j = 0; j < 3; j++) row[2][j] /= d->scale[2]; d->skew[1] /= d->scale[2]; d->skew[2] /= d->scale[2];
	double pdum[3]; cross3(pdum, row[1], row[2]);
	if (dot3(row[0], pdum) < 0) for (int i = 0; i < 3; i++) { d->scale[i] = -d->scale[i]; for (int j = 0; j < 3; j++) row[i][j] = -row[i][j]; }
	d->quat[0] = 0.5 * sqrt(fmax(1 + row[0][0] - row[1][1] - row[2][2], 0));
	d->quat[1] = 0.5 * sqrt(fmax(1 - row[0][0] + row[1][1] - row[2][2], 0));
	d->quat[2] = 0.5 * sqrt(fmax(1 - row[0][0] - row[1][1] + row[2][2], 0));
	d->quat[3] = 0.5 * sqrt(fmax(1 + row[0][0] + row[1][1] + row[2][2], 0));
	if (row[2][1] > row[1][2]) d->quat[0] = -d->quat[0];
	if (row[0][2] > row[2][0]) d->quat[1] = -d->quat[1];
	if (row[1][0] > row[0][1]) d->quat[2] = -d->quat[2];
	return 1;
}

static void rec4(double *m, const Dec4 *d)
{
	m4_identity(m);
	for (int i = 0; i < 4; i++) M4(m, i, 3) = d->persp[i];
	double t[16]; m4_identity(t); M4(t, 3, 0) = d->trans[0]; M4(t, 3, 1) = d->trans[1]; M4(t, 3, 2) = d->trans[2]; m4_mul(m, t, m);
	double x = d->quat[0], y = d->quat[1], z = d->quat[2], w = d->quat[3], r[16]; m4_identity(r);
	M4(r, 0, 0) = 1 - 2 * (y * y + z * z); M4(r, 0, 1) = 2 * (x * y + z * w); M4(r, 0, 2) = 2 * (x * z - y * w);
	M4(r, 1, 0) = 2 * (x * y - z * w); M4(r, 1, 1) = 1 - 2 * (x * x + z * z); M4(r, 1, 2) = 2 * (y * z + x * w);
	M4(r, 2, 0) = 2 * (x * z + y * w); M4(r, 2, 1) = 2 * (y * z - x * w); M4(r, 2, 2) = 1 - 2 * (x * x + y * y);
	m4_mul(m, r, m);
	if (d->skew[2]) { double k[16]; m4_identity(k); M4(k, 2, 1) = d->skew[2]; m4_mul(m, k, m); }
	if (d->skew[1]) { double k[16]; m4_identity(k); M4(k, 2, 0) = d->skew[1]; m4_mul(m, k, m); }
	if (d->skew[0]) { double k[16]; m4_identity(k); M4(k, 1, 0) = d->skew[0]; m4_mul(m, k, m); }
	double sc[16]; m4_identity(sc); sc[0] = d->scale[0]; sc[5] = d->scale[1]; sc[10] = d->scale[2]; m4_mul(m, sc, m);
}

void CAMat4Mix(double *out, const double *a, const double *b, double t)
{
	Dec4 A, B;
	if (!dec4(a, &A) || !dec4(b, &B)) { for (int i = 0; i < 16; i++) out[i] = t < 0.5 ? a[i] : b[i]; return; }
	Dec4 R;
	for (int i = 0; i < 4; i++) R.persp[i] = A.persp[i] + (B.persp[i] - A.persp[i]) * t;
	for (int i = 0; i < 3; i++) { R.trans[i] = A.trans[i] + (B.trans[i] - A.trans[i]) * t; R.scale[i] = A.scale[i] + (B.scale[i] - A.scale[i]) * t; R.skew[i] = A.skew[i] + (B.skew[i] - A.skew[i]) * t; }
	double dp = 0; for (int i = 0; i < 4; i++) dp += A.quat[i] * B.quat[i];
	if (dp > 1) dp = 1; if (dp < -1) dp = -1;
	double q[4]; memcpy(q, A.quat, sizeof q);
	if (fabs(dp) < 0.999999) {
		double theta = acos(dp), sinT = sin(theta), s1 = sin((1 - t) * theta) / sinT, s2 = sin(t * theta) / sinT;
		for (int i = 0; i < 4; i++) q[i] = A.quat[i] * s1 + B.quat[i] * s2;
	}
	memcpy(R.quat, q, sizeof q);
	rec4(out, &R);
}
