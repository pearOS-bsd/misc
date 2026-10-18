/* Animatable values: interpolation (-CA_interpolateValue:byFraction:) and addition (-CA_addValue:multipliedBy:) for numbers, structs, transforms, colors and arrays. */
#import "CAInternal.h"
#import "CAMatrix.h"
#include <string.h>

/* ---- colors ---------------------------------------------------------------------------------------------------------------------------------------------------------- */
static double ca_eotf(double v) { double a = fabs(v), l = a <= 0.04045 ? a / 12.92 : pow((a + 0.055) / 1.055, 2.4); return v < 0 ? -l : l; }
static double ca_oetf(double l) { double a = fabs(l), v = a <= 0.0031308 ? a * 12.92 : 1.055 * pow(a, 1 / 2.4) - 0.055; return l < 0 ? -v : v; }
static double ca_generic_trc(double v) { v = v < 0 ? 0 : (v > 1 ? 1 : v); return v <= 1.0 / 32 ? v / 16 : pow(v, 1.8); }

/* the Generic RGB / Generic Gray profile (gamma 1.8 with a linear toe) to linear sRGB */
static const double kGenericToLinearSRGB[3][3] = {
	{  1.0252418934870622,  0.0194007651682625, -0.0017621303582708164 },
	{ -0.026545244895289,   0.948008910922566,  -0.0014344936715375528 },
	{  0.0013035526008982408, 0.032590358561161346, 1.0031967449850745 } };

/* Opal does not name its colour spaces: a colour in an unnamed RGB space is taken as sRGB, or (WSCA_UNNAMED_IS_GENERIC=1, used by the tests that were recorded with Generic RGB colours) as Generic RGB */
static BOOL ca_space_is(CGColorSpaceRef cs, const char *name)
{
	if (!cs) return NO;
	CFStringRef n = CGColorSpaceCopyName(cs);
	if (!n) { static int generic = -1; if (generic < 0) generic = getenv("WSCA_UNNAMED_IS_GENERIC") != NULL; return generic && strstr(name, "Generic") != NULL; }
	char buf[96]; BOOL r = CFStringGetCString(n, buf, sizeof buf, kCFStringEncodingUTF8) && strstr(buf, name) != NULL; CFRelease(n); return r;
}

/* the components of a color in extended sRGB (the working space of color animations) */
void CAColorGetExtSRGB(CGColorRef c, double out[4])
{
	size_t n = CGColorGetNumberOfComponents(c); const CGFloat *p = CGColorGetComponents(c);
	CGColorSpaceRef cs = CGColorGetColorSpace(c);
	double a = n ? p[n - 1] : 1;
	if (n == 2 || (n < 3)) {                                           /* gray + alpha */
		double g = p[0];
		if (ca_space_is(cs, "Generic")) g = ca_oetf(ca_generic_trc(g));
		out[0] = out[1] = out[2] = g; out[3] = a; return;
	}
	if (ca_space_is(cs, "GenericRGB")) {
		double l[3] = { ca_generic_trc(p[0]), ca_generic_trc(p[1]), ca_generic_trc(p[2]) };
		for (int i = 0; i < 3; i++) out[i] = ca_oetf(kGenericToLinearSRGB[0][i] * l[0] + kGenericToLinearSRGB[1][i] * l[1] + kGenericToLinearSRGB[2][i] * l[2]);
	} else { out[0] = p[0]; out[1] = p[1]; out[2] = p[2]; }
	out[3] = a;
}

CGColorRef CAColorCreateExtSRGB(const double rgba[4])
{
	static CGColorSpaceRef cs;
	if (!cs) {
#ifdef __APPLE__
		cs = CGColorSpaceCreateWithName(kCGColorSpaceExtendedSRGB);
#endif
		if (!cs) cs = CGColorSpaceCreateDeviceRGB();
	}
	CGFloat c[4] = { rgba[0], rgba[1], rgba[2], rgba[3] };
	return CGColorCreate(cs, c);
}

static id ca_color_interpolate(CGColorRef a, CGColorRef b, float f)
{
	double x[4], y[4]; CAColorGetExtSRGB(a, x); CAColorGetExtSRGB(b, y);
	double fr = (double)f;
	for (int i = 0; i < 4; i++) x[i] = x[i] + (y[i] - x[i]) * fr;
	return CFBridgingRelease(CAColorCreateExtSRGB(x));
}

/* ---- structs of doubles ---------------------------------------------------------------------------------------------------------------------------------------------- */
typedef enum { kVTOther, kVTDoubles, kVTTransform3D, kVTAffine, kVTFloats } VType;
static VType ca_vtype(NSValue *v, size_t *n)
{
	const char *t = [v objCType]; if (!t) return kVTOther;
	if (strstr(t, "CATransform3D")) return kVTTransform3D;
	if (strstr(t, "AffineTransform")) return kVTAffine;
	if (t[0] != '{') return kVTOther;
	int d = 0, f = 0, o = 0;
	for (const char *p = t; *p; p++) {
		if (*p == '{') { while (*p && *p != '=') p++; if (!*p) break; }          /* skip the name of a (nested) struct */
		else if (*p == '}') continue;
		else if (*p == 'd') d++;
		else if (*p == 'f') f++;
		else o++;
	}
	if (o == 0 && d > 0 && f == 0) { *n = d; return kVTDoubles; }
	if (o == 0 && f > 0 && d == 0) { *n = f; return kVTFloats; }
	return kVTOther;
}

id CAValueInterpolate(id from, id to, float f)
{
	double fr = (double)f;
	if ([from isKindOfClass:[NSNumber class]] && [to isKindOfClass:[NSNumber class]]) {
		double a = [from doubleValue], b = [to doubleValue];
		return [NSNumber numberWithDouble:(a == b ? a : a + (b - a) * fr)];
	}
	if ([from isKindOfClass:[NSValue class]] && [to isKindOfClass:[NSValue class]]) {
		size_t n = 0; VType ta = ca_vtype(from, &n);
		if (ta == kVTTransform3D) {
			CATransform3D a = [from CATransform3DValue], b = [to CATransform3DValue], r;
			if (CATransform3DIsAffine(a) && CATransform3DIsAffine(b)) {
				double A[6] = { a.m11, a.m12, a.m21, a.m22, a.m41, a.m42 }, B[6] = { b.m11, b.m12, b.m21, b.m22, b.m41, b.m42 }, O[6];
				CAMat2Mix(O, A, B, fr);
				r = CATransform3DIdentity; r.m11 = O[0]; r.m12 = O[1]; r.m21 = O[2]; r.m22 = O[3]; r.m41 = O[4]; r.m42 = O[5];
			} else CAMat4Mix((double *)&r, (const double *)&a, (const double *)&b, fr);
			return [NSValue valueWithCATransform3D:r];
		}
		if (ta == kVTAffine) {
			CGAffineTransform a, b; [from getValue:&a]; [to getValue:&b];
			double A[6] = { a.a, a.b, a.c, a.d, a.tx, a.ty }, B[6] = { b.a, b.b, b.c, b.d, b.tx, b.ty }, O[6];
			CAMat2Mix(O, A, B, fr);
			CGAffineTransform r = CGAffineTransformMake(O[0], O[1], O[2], O[3], O[4], O[5]);
			return [NSValue valueWithBytes:&r objCType:@encode(CGAffineTransform)];
		}
		if (ta == kVTDoubles) {
			double a[64], b[64], r[64]; [from getValue:a]; [to getValue:b];
			for (size_t i = 0; i < n && i < 64; i++) r[i] = a[i] == b[i] ? a[i] : a[i] + (b[i] - a[i]) * fr;
			return [NSValue valueWithBytes:r objCType:[from objCType]];
		}
		if (ta == kVTFloats) {
			float a[64], b[64], r[64]; [from getValue:a]; [to getValue:b];
			for (size_t i = 0; i < n && i < 64; i++) r[i] = a[i] + (b[i] - a[i]) * f;
			return [NSValue valueWithBytes:r objCType:[from objCType]];
		}
		return f < 0.5f ? from : to;
	}
	if (from && to && CAIsColor(from) && CAIsColor(to))
		return ca_color_interpolate((__bridge CGColorRef)from, (__bridge CGColorRef)to, f);
	if ([from isKindOfClass:[NSArray class]] && [to isKindOfClass:[NSArray class]] && [from count] == [to count]) {
		NSMutableArray *r = [NSMutableArray arrayWithCapacity:[from count]];
		for (NSUInteger i = 0; i < [from count]; i++) [r addObject:CAValueInterpolate(from[i], to[i], f)];
		return r;
	}
	return f < 0.5f ? from : to;
}

id CAValueAdd(id base, id other, int k)
{
	if ([base isKindOfClass:[NSNumber class]] && [other isKindOfClass:[NSNumber class]])
		return [NSNumber numberWithDouble:[other doubleValue] * (double)k + [base doubleValue]];
	if ([base isKindOfClass:[NSValue class]] && [other isKindOfClass:[NSValue class]]) {
		size_t n = 0; VType ta = ca_vtype(base, &n);
		if (ta == kVTDoubles) {
			double a[64], b[64], r[64]; [base getValue:a]; [other getValue:b];
			for (size_t i = 0; i < n && i < 64; i++) r[i] = a[i] + b[i] * (double)k;
			return [NSValue valueWithBytes:r objCType:[base objCType]];
		}
		if (ta == kVTTransform3D) {
			CATransform3D a = [base CATransform3DValue], b = [other CATransform3DValue];
			CATransform3D p = CATransform3DIdentity; int m = k < 0 ? -k : k; CATransform3D unit = k < 0 ? CATransform3DInvert(b) : b;
			for (int i = 0; i < m; i++) p = CATransform3DConcat(p, unit);
			return [NSValue valueWithCATransform3D:CATransform3DConcat(p, a)];
		}
	}
	if (base && other && CAIsColor(base) && CAIsColor(other)) {
		double x[4], y[4]; CAColorGetExtSRGB((__bridge CGColorRef)base, x); CAColorGetExtSRGB((__bridge CGColorRef)other, y);
		for (int i = 0; i < 4; i++) x[i] = x[i] + y[i] * (double)k;
		return CFBridgingRelease(CAColorCreateExtSRGB(x));
	}
	if ([base isKindOfClass:[NSArray class]] && [other isKindOfClass:[NSArray class]] && [base count] == [other count]) {
		NSMutableArray *r = [NSMutableArray array];
		for (NSUInteger i = 0; i < [base count]; i++) [r addObject:CAValueAdd(base[i], other[i], k)];
		return r;
	}
	return base;
}
