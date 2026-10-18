/* prints bit-exact results of the public CATransform3D functions on fixed inputs: built against the real QuartzCore, or (with -DOURS) against this implementation */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
static void P(const char *n, CATransform3D m) { CGFloat *f = (CGFloat *)&m; printf("%s", n); for (int i = 0; i < 16; i++) { union { double d; uint64_t u; } u = { f[i] }; printf(" %016llx", (unsigned long long)u.u); } printf("\n"); }
static uint64_t s = 88172645463325252ULL;
static double rnd(void) { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return ((double)(s >> 11) / 9007199254740992.0) * 4 - 2; }
int main(void)
{
	P("identity", CATransform3DIdentity);
	for (int i = 0; i < 12; i++) {
		CATransform3D a, b; CGFloat *fa = (CGFloat *)&a, *fb = (CGFloat *)&b;
		for (int k = 0; k < 16; k++) { fa[k] = rnd(); fb[k] = rnd(); }
		if (i % 3 == 0) { a = CATransform3DMakeTranslation(rnd(), rnd(), rnd()); b = CATransform3DMakeScale(rnd(), rnd(), rnd()); }
		if (i % 3 == 1) { a = CATransform3DMakeRotation(rnd(), rnd(), rnd(), rnd()); b = CATransform3DMakeRotation(rnd(), 0, 0, 1); }
		P("A", a); P("B", b);
		P("concat", CATransform3DConcat(a, b));
		P("invert", CATransform3DInvert(a));
		P("translate", CATransform3DTranslate(a, 1.5, -2.25, 0.75));
		P("scale", CATransform3DScale(a, 1.5, -2.25, 0.75));
		P("rotate", CATransform3DRotate(a, 0.7, 0.3, -0.5, 0.8));
		P("rotz", CATransform3DRotate(a, 1.1, 0, 0, 1));
		P("makeRot", CATransform3DMakeRotation(0.9, 1, 2, 3));
		printf("isId %d isAff %d eq %d\n", CATransform3DIsIdentity(a), CATransform3DIsAffine(a), CATransform3DEqualToTransform(a, a));
		CGAffineTransform af = CATransform3DGetAffineTransform(a); printf("aff %.17g %.17g %.17g %.17g %.17g %.17g\n", af.a, af.b, af.c, af.d, af.tx, af.ty);
		P("fromAff", CATransform3DMakeAffineTransform(CGAffineTransformMake(1.5, 0.25, -0.5, 2, 3, 4)));
	}
	return 0;
}
