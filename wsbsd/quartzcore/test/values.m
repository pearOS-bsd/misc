/* Value interpolation and addition, against the real QuartzCore (through the private -CA_interpolateValue:byFraction: / -CA_addValue:multipliedBy: when built with -DREAL_CA). */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#ifndef REAL_CA
#import "../src/CAInternal.h"
#endif

static uint64_t s = 0x9E3779B97F4A7C15ULL;
static double rnd(void) { s ^= s << 13; s ^= s >> 7; s ^= s << 17; return ((double)(s >> 11) / 9007199254740992.0); }
static double R(double a, double b) { return a + rnd() * (b - a); }

static id interp(id a, id b, float f)
{
#ifdef REAL_CA
	return ((id (*)(id, SEL, id, float))objc_msgSend)(a, NSSelectorFromString(@"CA_interpolateValue:byFraction:"), b, f);
#else
	return CAValueInterpolate(a, b, f);
#endif
}
static id add(id a, id b, int n)
{
#ifdef REAL_CA
	return ((id (*)(id, SEL, id, int))objc_msgSend)(a, NSSelectorFromString(@"CA_addValue:multipliedBy:"), b, n);
#else
	return CAValueAdd(a, b, n);
#endif
}
static void show(const char *tag, id v)
{
	NSMutableString *o = [NSMutableString stringWithFormat:@"%s ", tag];
	if (!v) [o appendString:@"nil"];
	else if ([v isKindOfClass:[NSNumber class]]) [o appendFormat:@"%.12g", [v doubleValue]];
	else if (CFGetTypeID((__bridge CFTypeRef)v) == CGColorGetTypeID()) {
		CGColorRef c = (__bridge CGColorRef)v; size_t n = CGColorGetNumberOfComponents(c); const CGFloat *p = CGColorGetComponents(c);
		for (size_t i = 0; i < n; i++) [o appendFormat:@"%.9g ", p[i]];
	} else if ([v isKindOfClass:[NSValue class]]) {
		const char *t = [v objCType]; double buf[32] = { 0 }; [v getValue:buf];
		int n = (int)strlen(t) > 0 ? 0 : 0; (void)n;
		size_t sz = 0; NSGetSizeAndAlignment(t, &sz, NULL);
		for (size_t i = 0; i < sz / 8; i++) [o appendFormat:@"%.12g ", buf[i]];
	}
	printf("%s\n", [o UTF8String]);
}

int main(void)
{
	@autoreleasepool {
		for (int i = 0; i < 40; i++) {
			float f = i % 5 == 0 ? 0.0f : (i % 5 == 4 ? 1.0f : (float)rnd());
			show("num", interp(@(R(-5, 5)), @(R(-5, 5)), f));
			double v = R(-3, 3); show("num-eq", interp(@(v), @(v), f));
			show("point", interp([NSValue valueWithPoint:NSMakePoint(R(-9, 9), R(-9, 9))], [NSValue valueWithPoint:NSMakePoint(R(-9, 9), R(-9, 9))], f));
			show("size", interp([NSValue valueWithSize:NSMakeSize(R(0, 90), R(0, 90))], [NSValue valueWithSize:NSMakeSize(R(0, 90), R(0, 90))], f));
			show("rect", interp([NSValue valueWithRect:NSMakeRect(R(-9, 9), R(-9, 9), R(0, 90), R(0, 90))], [NSValue valueWithRect:NSMakeRect(R(-9, 9), R(-9, 9), R(0, 90), R(0, 90))], f));
			show("add-num", add(@(R(-5, 5)), @(R(-5, 5)), (i % 4) - 1));
			show("add-pt", add([NSValue valueWithPoint:NSMakePoint(R(-9, 9), R(-9, 9))], [NSValue valueWithPoint:NSMakePoint(R(-9, 9), R(-9, 9))], (i % 3) + 1));
			/* 2D affine transform as CATransform3D, and as CGAffineTransform */
			CATransform3D a = CATransform3DMakeRotation(R(-3.5, 3.5), 0, 0, 1), b = CATransform3DMakeRotation(R(-3.5, 3.5), 0, 0, 1);
			a = CATransform3DScale(a, R(0.2, 3), R(0.2, 3), 1); b = CATransform3DScale(b, R(0.2, 3), R(0.2, 3), 1);
			a = CATransform3DTranslate(a, R(-50, 50), R(-50, 50), 0); b = CATransform3DTranslate(b, R(-50, 50), R(-50, 50), 0);
			if (i % 7 == 3) a = CATransform3DScale(a, -1, 1, 1);
			if (i % 7 == 5) { a = CATransform3DMakeScale(R(0.2, 3), 1, 1); b = CATransform3DMakeRotation(R(-3, 3), 0, 0, 1); }
			if (getenv("SHOWIN")) { CGFloat *pa=(CGFloat*)&a,*pb=(CGFloat*)&b; printf("in f=%g A:",f); for(int k=0;k<16;k++) printf(" %.17g",pa[k]); printf(" B:"); for(int k=0;k<16;k++) printf(" %.17g",pb[k]); printf("\n"); }
			show("mat4-2d", interp([NSValue valueWithCATransform3D:a], [NSValue valueWithCATransform3D:b], f));
			CGAffineTransform aa = CGAffineTransformMake(R(-2, 2), R(-2, 2), R(-2, 2), R(-2, 2), R(-9, 9), R(-9, 9)), bb = CGAffineTransformMake(R(-2, 2), R(-2, 2), R(-2, 2), R(-2, 2), R(-9, 9), R(-9, 9));
			show("affine", interp([NSValue valueWithBytes:&aa objCType:@encode(CGAffineTransform)], [NSValue valueWithBytes:&bb objCType:@encode(CGAffineTransform)], f));
			/* colors */
			CGColorRef c1 = CGColorCreateGenericRGB(R(0, 1), R(0, 1), R(0, 1), R(0.2, 1)), c2 = CGColorCreateGenericRGB(R(0, 1), R(0, 1), R(0, 1), R(0.2, 1));
			show("color", interp((__bridge id)c1, (__bridge id)c2, f));
			CGColorSpaceRef srgb = CGColorSpaceCreateWithName(kCGColorSpaceSRGB); CGFloat p1[4] = { R(0, 1), R(0, 1), R(0, 1), 1 }, p2[4] = { R(0, 1), R(0, 1), R(0, 1), 1 };
			CGColorRef d1 = CGColorCreate(srgb, p1), d2 = CGColorCreate(srgb, p2); show("color-srgb", interp((__bridge id)d1, (__bridge id)d2, f));
			/* discrete */
			show("string", interp(@"a", @"b", f));
		}
	}
	return 0;
}
