/* Randomised differential scenarios (fuzz): the same source is built against the real QuartzCore (make fuzz) and against this implementation (make check-fuzz); the printed values must be identical.
 * An animation is sampled by freezing it (speed 0, timeOffset t) and reading the presentation layer. */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import "cacompat.h"
#ifdef REAL_CA
#import <Metal/Metal.h>
#endif

static CALayer *L;
static void setup(void)
{
#ifdef REAL_CA
	id<MTLDevice> dev = MTLCreateSystemDefaultDevice();
	MTLTextureDescriptor *td = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:100 height:100 mipmapped:NO];
	td.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
	static CARenderer *R;
	R = [CARenderer rendererWithMTLTexture:[dev newTextureWithDescriptor:td] options:nil];
	L = [CALayer layer];
	R.layer = L; R.bounds = CGRectMake(0, 0, 400, 300);
#else
	static CARenderer *R;
	R = [CARenderer rendererWithBitmap:NULL width:400 height:300 bytesPerRow:1600 options:nil];
	L = [CALayer layer];
	R.layer = L; R.bounds = CGRectMake(0, 0, 400, 300);
#endif
	L.frame = CGRectMake(10, 20, 100, 50);
	[CATransaction flush];
}

static void fmtv(NSMutableString *s, id v)
{
	if (!v) { [s appendString:@"nil"]; return; }
	if ([v isKindOfClass:[NSNumber class]]) { [s appendFormat:@"%.9g", [v doubleValue]]; return; }
	if (CAIsColor(v)) {
		CGColorRef c = (__bridge CGColorRef)v; size_t n = CGColorGetNumberOfComponents(c); const CGFloat *p = CGColorGetComponents(c);
		[s appendString:@"color("]; for (size_t i = 0; i < n; i++) [s appendFormat:@"%s%.6g", i ? "," : "", p[i]]; [s appendString:@")"]; return;
	}
	if ([v isKindOfClass:[NSValue class]]) {
		const char *t = [v objCType];
		if (!strcmp(t, @encode(CGPoint))) { CGPoint p = [v pointValue]; [s appendFormat:@"(%.9g,%.9g)", p.x, p.y]; return; }
		if (!strcmp(t, @encode(CGSize))) { CGSize p = [v sizeValue]; [s appendFormat:@"[%.9g,%.9g]", p.width, p.height]; return; }
		if (!strcmp(t, @encode(CGRect))) { CGRect r = [v rectValue]; [s appendFormat:@"{%.9g,%.9g,%.9g,%.9g}", r.origin.x, r.origin.y, r.size.width, r.size.height]; return; }
		if (!strcmp(t, @encode(CATransform3D))) { CATransform3D m = [v CATransform3DValue]; CGFloat *f = (CGFloat *)&m; [s appendString:@"T["]; for (int i = 0; i < 16; i++) [s appendFormat:@"%s%.6g", i ? " " : "", f[i]]; [s appendString:@"]"]; return; }
	}
	[s appendFormat:@"%@", v];
}

static NSString *getk(CALayer *p, NSString *kp) { NSMutableString *s = [NSMutableString string]; fmtv(s, [p valueForKeyPath:kp]); return s; }


static uint64_t rs = 0x2545F4914F6CDD1DULL;
static double rnd(void) { rs ^= rs << 13; rs ^= rs >> 7; rs ^= rs << 17; return (double)(rs >> 11) / 9007199254740992.0; }
static double R(double a, double b) { return a + rnd() * (b - a); }
static int RI(int n) { return (int)(rnd() * n); }
#define NUM(x) [NSNumber numberWithDouble:x]
static CAMediaTimingFunction *rtf(void)
{
	switch (RI(7)) {
	case 0: return nil;
	case 1: return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear];
	case 2: return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
	case 3: return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
	case 4: return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
	case 5: return [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
	default: return [CAMediaTimingFunction functionWithControlPoints:(float)R(0, 1) :(float)R(-0.5, 1.5) :(float)R(0, 1) :(float)R(-0.5, 1.5)];
	}
}
static NSString *rfill(void) { NSString *f[] = { kCAFillModeRemoved, kCAFillModeForwards, kCAFillModeBackwards, kCAFillModeBoth }; return f[RI(4)]; }
static const char *kps[] = { "opacity", "position", "bounds", "cornerRadius", "transform.rotation.z", "transform.scale", "transform.translation.x", "position.x", "backgroundColor", "bounds.size.width", "shadowOffset", "transform" };
static id val(int k)
{
	switch (k) {
	case 0: return NUM(R(0, 1));
	case 1: return [NSValue valueWithPoint:NSMakePoint(R(-50, 150), R(-50, 150))];
	case 2: return [NSValue valueWithRect:NSMakeRect(R(0, 20), R(0, 20), R(10, 200), R(10, 200))];
	case 3: return NUM(R(0, 30));
	case 4: return NUM(R(-3, 3));
	case 5: return NUM(R(0.3, 3));
	case 6: return NUM(R(-80, 80));
	case 7: return NUM(R(-50, 150));
	case 8: return (__bridge id)CGColorCreateGenericRGB(R(0, 1), R(0, 1), R(0, 1), R(0.3, 1));
	case 9: return NUM(R(10, 300));
	case 10: return [NSValue valueWithSize:NSMakeSize(R(-10, 10), R(-10, 10))];
	default: { CATransform3D t = CATransform3DMakeRotation(R(-3, 3), 0, 0, 1); t = CATransform3DScale(t, R(0.3, 2), R(0.3, 2), 1); t = CATransform3DTranslate(t, R(-30, 30), R(-30, 30), 0); return [NSValue valueWithCATransform3D:t]; }
	}
}
static void timing(CAAnimation *a)
{
	if (RI(5)) a.duration = R(0.1, 3);
	if (!RI(3)) a.speed = (float)R(0.3, 3);
	if (!RI(6)) a.speed = (float)R(-2, 0);
	if (!RI(4)) a.timeOffset = R(0, 1.5);
	if (!RI(4)) a.beginTime = R(0.2, 2);
	if (!RI(4)) a.repeatCount = (float)(RI(3) + R(0, 1));
	else if (!RI(6)) a.repeatDuration = R(0.3, 6);
	if (!RI(3)) a.autoreverses = YES;
	a.fillMode = rfill();
	a.timingFunction = rtf();
	a.removedOnCompletion = NO;
}
int main(void)
{
	setvbuf(stdout, NULL, _IONBF, 0);
	@autoreleasepool {
		setup();
		int N = getenv("FUZZ_N") ? atoi(getenv("FUZZ_N")) : 1500;
		for (int n = 0; n < N; n++) {
			int k = RI(12);
			NSString *kp = [NSString stringWithUTF8String:kps[k]];
			NSString *rkp = k == 4 || k == 5 || k == 6 || k == 11 ? @"transform" : (k == 7 ? @"position" : (k == 9 ? @"bounds" : kp));
			CAAnimation *an = nil; int kind = RI(8);
			if (kind <= 3) {
				CABasicAnimation *b = [CABasicAnimation animationWithKeyPath:kp];
				int m = RI(5);
				if (m == 0 || m == 1) { b.fromValue = val(k); b.toValue = val(k); }
				else if (m == 2) b.toValue = val(k);
				else if (m == 3) b.fromValue = val(k);
				else if (k == 0 || k == 3 || k == 4 || k == 5 || k == 6 || k == 7 || k == 9) b.byValue = val(k); else { b.fromValue = val(k); b.toValue = val(k); }
				if (k != 8 && k != 11 && !RI(5)) { b.additive = YES; if (!RI(2)) b.cumulative = YES; }
				an = b; timing(an);
			} else if (kind <= 5) {
				CAKeyframeAnimation *kf = [CAKeyframeAnimation animationWithKeyPath:kp];
				int cnt = 2 + RI(4); NSMutableArray *vs = [NSMutableArray array]; for (int i = 0; i < cnt; i++) [vs addObject:val(k)];
				kf.values = vs; NSString *modes[] = { kCAAnimationLinear, kCAAnimationDiscrete, kCAAnimationPaced, kCAAnimationCubic, kCAAnimationCubicPaced };
				kf.calculationMode = modes[RI(5)];
				if (!RI(3) && [kf.calculationMode isEqualToString:kCAAnimationLinear]) { NSMutableArray *ts = [NSMutableArray array]; double t = 0; for (int i = 0; i < cnt; i++) { [ts addObject:NUM(i == cnt - 1 ? 1 : t)]; t += (1 - t) * R(0.1, 0.6); } kf.keyTimes = ts; }
				if (!RI(3) && [kf.calculationMode isEqualToString:kCAAnimationLinear]) { NSMutableArray *fs = [NSMutableArray array]; for (int i = 0; i < cnt - 1; i++) [fs addObject:rtf() ?: [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear]]; kf.timingFunctions = fs; }
				if (k != 8 && k != 11 && !RI(5)) kf.additive = YES;
				an = kf; timing(an);
			} else if (kind == 6) {
				CASpringAnimation *sp = [CASpringAnimation animationWithKeyPath:kp];
				sp.mass = R(0.5, 3); sp.stiffness = R(30, 500); sp.damping = R(2, 60); sp.initialVelocity = R(-5, 5); sp.allowsOverdamping = RI(2);
				sp.fromValue = val(k); sp.toValue = val(k);
				sp.duration = RI(2) ? sp.settlingDuration : R(0.2, 2); sp.fillMode = rfill(); sp.removedOnCompletion = NO;
				if (!RI(3)) sp.beginTime = R(0.2, 1);
				an = sp;
			} else {
				CAAnimationGroup *g = [CAAnimationGroup animation]; NSMutableArray *kids = [NSMutableArray array];
				int cnt = 1 + RI(3);
				for (int i = 0; i < cnt; i++) { CABasicAnimation *b = [CABasicAnimation animationWithKeyPath:kp]; b.fromValue = val(k); b.toValue = val(k); timing(b); [kids addObject:b]; }
				g.animations = kids; timing(g); g.duration = R(0.5, 4);
				an = g;
			}
			/* the layer's time is frozen at T0 + tau; the animation is added at T0 */
			double T0 = R(0, 5), tau = R(-0.3, 4);
			[L removeAllAnimations]; L.speed = 1; L.timeOffset = 0;
			[CATransaction begin]; [CATransaction setDisableActions:YES];
			L.opacity = 1; L.position = CGPointMake(60, 45); L.bounds = CGRectMake(0, 0, 100, 50); L.cornerRadius = 0; L.transform = CATransform3DIdentity; L.backgroundColor = NULL; L.shadowOffset = CGSizeMake(0, -3);
			[CATransaction commit]; [CATransaction flush];
			L.speed = 0; L.timeOffset = T0; [CATransaction flush];
			[L addAnimation:an forKey:@"a"]; [CATransaction flush];
			L.timeOffset = T0 + tau; [CATransaction flush];
			CALayer *p = [L presentationLayer];
			printf("#%d kind=%d key=%s tau=%.4f %s\n", n, kind, kps[k], tau, [getk(p, rkp) UTF8String]);
			if (getenv("FUZZ_DESC")) { CAAnimation *x = an; printf("   desc: %s dur=%g speed=%g off=%g begin=%g rep=%g repd=%g auto=%d fill=%s", [NSStringFromClass([x class]) UTF8String], x.duration, x.speed, x.timeOffset, x.beginTime, x.repeatCount, x.repeatDuration, x.autoreverses, [x.fillMode UTF8String]); if ([x isKindOfClass:[CAKeyframeAnimation class]]) { CAKeyframeAnimation *q = (CAKeyframeAnimation *)x; printf(" mode=%s n=%d keyTimes=%d tfs=%d", [q.calculationMode UTF8String], (int)q.values.count, (int)q.keyTimes.count, (int)q.timingFunctions.count); } printf("\n"); }
		}
	}
	return 0;
}
