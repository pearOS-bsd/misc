/* CATransform3D: the matrix functions. The operation order and the arithmetic follow QuartzCore (checked bit by bit by test/xform). */
#include <QuartzCore/CATransform3D.h>
#include <math.h>
#include <string.h>

const CATransform3D CATransform3DIdentity = { 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1 };

bool CATransform3DIsIdentity(CATransform3D t) { return memcmp(&t, &CATransform3DIdentity, sizeof t) == 0 || CATransform3DEqualToTransform(t, CATransform3DIdentity); }

bool CATransform3DEqualToTransform(CATransform3D a, CATransform3D b)
{
	const CGFloat *p = &a.m11, *q = &b.m11;
	for (int i = 0; i < 16; i++) if (!(p[i] == q[i])) return false;
	return true;
}

CATransform3D CATransform3DMakeTranslation(CGFloat tx, CGFloat ty, CGFloat tz) { CATransform3D t = CATransform3DIdentity; t.m41 = tx; t.m42 = ty; t.m43 = tz; return t; }
CATransform3D CATransform3DMakeScale(CGFloat sx, CGFloat sy, CGFloat sz) { CATransform3D t = CATransform3DIdentity; t.m11 = sx; t.m22 = sy; t.m33 = sz; return t; }

CATransform3D CATransform3DMakeRotation(CGFloat angle, CGFloat x, CGFloat y, CGFloat z)
{
	CATransform3D t = CATransform3DIdentity;
	double s = sin(angle), c = cos(angle);
	if (fabs(s) < 1e-7) { c = copysign(1.0, c); s = 0; }                       /* exact values at the multiples of a quarter turn */
	else if (fabs(c) < 1e-7) { s = copysign(1.0, s); c = 0; }
	if (x == 0 && y == 0 && z == 1) { t.m11 = c; t.m12 = s; t.m21 = -s; t.m22 = c; return t; }
	if (x == 0 && y == 1 && z == 0) { t.m11 = c; t.m13 = -s; t.m31 = s; t.m33 = c; return t; }
	if (x == 1 && y == 0 && z == 0) { t.m22 = c; t.m23 = s; t.m32 = -s; t.m33 = c; return t; }
	double x2 = x * x, y2 = y * y, z2 = z * z, len = sqrt(y2 + x2 + z2);
	if (fabs(len) < 1e-6) return t;
	if (len != 1) { double k = 1.0 / len; x *= k; y *= k; z *= k; x2 = x * x; y2 = y * y; z2 = z * z; }
	double k = 1.0 - c, xyk = y * k * x, yzk = y * k * z, zxk = z * x * k, xs = x * s, ys = y * s, zs = z * s;
	t.m11 = (1.0 - x2) * c + x2;   t.m12 = xyk + zs;   t.m13 = zxk - ys;
	t.m21 = xyk - zs;              t.m22 = (1.0 - y2) * c + y2;   t.m23 = yzk + xs;
	t.m31 = zxk + ys;              t.m32 = yzk - xs;   t.m33 = (1.0 - z2) * c + z2;
	return t;
}

CATransform3D CATransform3DConcat(CATransform3D a, CATransform3D b)
{
	CATransform3D r; const CGFloat *p = &a.m11, *q = &b.m11; CGFloat *o = &r.m11;
	for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++)
		o[i * 4 + j] = p[i * 4 + 0] * q[0 * 4 + j] + p[i * 4 + 1] * q[1 * 4 + j] + p[i * 4 + 2] * q[2 * 4 + j] + p[i * 4 + 3] * q[3 * 4 + j];
	return r;
}

CATransform3D CATransform3DTranslate(CATransform3D t, CGFloat tx, CGFloat ty, CGFloat tz) { return CATransform3DConcat(CATransform3DMakeTranslation(tx, ty, tz), t); }
CATransform3D CATransform3DScale(CATransform3D t, CGFloat sx, CGFloat sy, CGFloat sz) { return CATransform3DConcat(CATransform3DMakeScale(sx, sy, sz), t); }
CATransform3D CATransform3DRotate(CATransform3D t, CGFloat angle, CGFloat x, CGFloat y, CGFloat z) { return CATransform3DConcat(CATransform3DMakeRotation(angle, x, y, z), t); }

CATransform3D CATransform3DInvert(CATransform3D t)
{
	/* cofactors of the 2x2 minors, as in the classic closed form; a singular matrix comes back unchanged */
	const CGFloat *m = &t.m11;
	double s0 = m[0] * m[5] - m[4] * m[1], s1 = m[0] * m[6] - m[4] * m[2], s2 = m[0] * m[7] - m[4] * m[3];
	double s3 = m[1] * m[6] - m[5] * m[2], s4 = m[1] * m[7] - m[5] * m[3], s5 = m[2] * m[7] - m[6] * m[3];
	double c5 = m[10] * m[15] - m[14] * m[11], c4 = m[9] * m[15] - m[13] * m[11], c3 = m[9] * m[14] - m[13] * m[10];
	double c2 = m[8] * m[15] - m[12] * m[11], c1 = m[8] * m[14] - m[12] * m[10], c0 = m[8] * m[13] - m[12] * m[9];
	double det = s0 * c5 - s1 * c4 + s2 * c3 + s3 * c2 - s4 * c1 + s5 * c0;
	if (det == 0 || !isfinite(det)) return t;
	double id = 1.0 / det; CATransform3D r; CGFloat *o = &r.m11;
	o[0]  = ( m[5] * c5 - m[6] * c4 + m[7] * c3) * id;
	o[1]  = (-m[1] * c5 + m[2] * c4 - m[3] * c3) * id;
	o[2]  = ( m[13] * s5 - m[14] * s4 + m[15] * s3) * id;
	o[3]  = (-m[9] * s5 + m[10] * s4 - m[11] * s3) * id;
	o[4]  = (-m[4] * c5 + m[6] * c2 - m[7] * c1) * id;
	o[5]  = ( m[0] * c5 - m[2] * c2 + m[3] * c1) * id;
	o[6]  = (-m[12] * s5 + m[14] * s2 - m[15] * s1) * id;
	o[7]  = ( m[8] * s5 - m[10] * s2 + m[11] * s1) * id;
	o[8]  = ( m[4] * c4 - m[5] * c2 + m[7] * c0) * id;
	o[9]  = (-m[0] * c4 + m[1] * c2 - m[3] * c0) * id;
	o[10] = ( m[12] * s4 - m[13] * s2 + m[15] * s0) * id;
	o[11] = (-m[8] * s4 + m[9] * s2 - m[11] * s0) * id;
	o[12] = (-m[4] * c3 + m[5] * c1 - m[6] * c0) * id;
	o[13] = ( m[0] * c3 - m[1] * c1 + m[2] * c0) * id;
	o[14] = (-m[12] * s3 + m[13] * s1 - m[14] * s0) * id;
	o[15] = ( m[8] * s3 - m[9] * s1 + m[10] * s0) * id;
	return r;
}

CATransform3D CATransform3DMakeAffineTransform(CGAffineTransform m)
{
	CATransform3D t = CATransform3DIdentity; t.m11 = m.a; t.m12 = m.b; t.m21 = m.c; t.m22 = m.d; t.m41 = m.tx; t.m42 = m.ty; return t;
}
bool CATransform3DIsAffine(CATransform3D t) { return t.m13 == 0 && t.m14 == 0 && t.m23 == 0 && t.m24 == 0 && t.m31 == 0 && t.m32 == 0 && t.m33 == 1 && t.m34 == 0 && t.m43 == 0 && t.m44 == 1; }
CGAffineTransform CATransform3DGetAffineTransform(CATransform3D t) { return CGAffineTransformMake(t.m11, t.m12, t.m21, t.m22, t.m41, t.m42); }
