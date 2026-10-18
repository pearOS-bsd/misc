/* Differential scenarios: the same source is built against the real QuartzCore (make golden) and against this implementation (make check-golden); the printed values must be identical.
 * An animation is sampled by freezing it (speed 0, timeOffset t) and reading the presentation layer. */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
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
	if (CFGetTypeID((__bridge CFTypeRef)v) == CGColorGetTypeID()) {
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

/* sample the animation at local times t0 .. t1 */
static void run(const char *name, CAAnimation *a, NSString *kp, double t0, double t1, double step)
{
	printf("## %s\n", name);
	for (double t = t0; t <= t1 + 1e-9; t += step) {
		CAAnimation *c = [a copy];
		/* the freeze: local time of the animation as if the host layer were at time t */
		c.speed = 0 * c.speed; c.timeOffset = t + c.timeOffset;
		[L removeAllAnimations]; [L addAnimation:c forKey:@"a"]; [CATransaction flush];
		printf("t=%.4g %s\n", t, [getk([L presentationLayer], kp) UTF8String]);
	}
}

static CAMediaTimingFunction *tf(NSString *n) { return [CAMediaTimingFunction functionWithName:n]; }
static CABasicAnimation *basic(NSString *kp, id from, id to, double dur)
{
	CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:kp]; a.fromValue = from; a.toValue = to; a.duration = dur; a.fillMode = kCAFillModeBoth; a.removedOnCompletion = NO; return a;
}
#define NUM(x) [NSNumber numberWithDouble:x]
#define PT(x, y) [NSValue valueWithPoint:NSMakePoint(x, y)]

int main(void)
{
	setvbuf(stdout, NULL, _IONBF, 0);
	@autoreleasepool {
		setup();
		printf("# defaults\n");
		printf("layer: opacity=%s pos=%s bounds=%s anchor=%s tx=%s\n", [getk(L, @"opacity") UTF8String], [getk(L, @"position") UTF8String], [getk(L, @"bounds") UTF8String], [getk(L, @"anchorPoint") UTF8String], [getk(L, @"transform") UTF8String]);
		/* every named timing function through a basic animation */
		for (NSString *n in @[kCAMediaTimingFunctionLinear, kCAMediaTimingFunctionEaseIn, kCAMediaTimingFunctionEaseOut, kCAMediaTimingFunctionEaseInEaseOut, kCAMediaTimingFunctionDefault]) {
			CABasicAnimation *a = basic(@"opacity", NUM(0), NUM(1), 1); a.timingFunction = tf(n);
			run([[NSString stringWithFormat:@"basic opacity %@", n] UTF8String], a, @"opacity", -0.1, 1.1, 0.05);
		}
		{ CABasicAnimation *a = basic(@"opacity", NUM(0), NUM(1), 2); a.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.1 :0.9 :0.2 :1.0];
		  run("basic custom bezier .1 .9 .2 1", a, @"opacity", 0, 2, 0.1); }
		{ CABasicAnimation *a = basic(@"opacity", NUM(0.2), NUM(0.9), 1); a.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.7 :-0.5 :0.3 :1.5];
		  run("basic overshoot bezier", a, @"opacity", 0, 1, 0.05); }
		{ CABasicAnimation *a = basic(@"position", PT(0, 0), PT(200, 100), 1); a.timingFunction = tf(kCAMediaTimingFunctionEaseInEaseOut); run("basic position", a, @"position", 0, 1, 0.125); }
		{ CABasicAnimation *a = basic(@"bounds", [NSValue valueWithRect:NSMakeRect(0, 0, 10, 10)], [NSValue valueWithRect:NSMakeRect(0, 0, 100, 60)], 1); run("basic bounds", a, @"bounds", 0, 1, 0.25); }
		{ CABasicAnimation *a = basic(@"transform.rotation.z", NUM(0), NUM(M_PI), 1); run("basic rotation.z", a, @"transform", 0, 1, 0.25); }
		{ CABasicAnimation *a = basic(@"transform.scale", NUM(1), NUM(2), 1); run("basic scale", a, @"transform", 0, 1, 0.25); }
		{ CABasicAnimation *a = basic(@"transform.translation.x", NUM(0), NUM(50), 1); run("basic translation.x", a, @"transform", 0, 1, 0.25); }
		{ CATransform3D a0 = CATransform3DMakeRotation(0, 0, 0, 1), a1 = CATransform3DScale(CATransform3DMakeRotation(M_PI / 2, 0, 0, 1), 2, 2, 1);
		  CABasicAnimation *a = basic(@"transform", [NSValue valueWithCATransform3D:a0], [NSValue valueWithCATransform3D:a1], 1); run("basic transform matrix", a, @"transform", 0, 1, 0.25); }
		{ CABasicAnimation *a = basic(@"backgroundColor", (__bridge id)CGColorCreateGenericRGB(1, 0, 0, 1), (__bridge id)CGColorCreateGenericRGB(0, 0, 1, 1), 1); run("basic color", a, @"backgroundColor", 0, 1, 0.25); }
		{ CABasicAnimation *a = basic(@"cornerRadius", NUM(0), NUM(10), 1); a.byValue = nil; run("basic cornerRadius", a, @"cornerRadius", 0, 1, 0.5); }
		{ CABasicAnimation *a = basic(@"opacity", nil, NUM(0), 1); run("basic to only (from model)", a, @"opacity", 0, 1, 0.25); }
		{ CABasicAnimation *a = basic(@"opacity", NUM(0), nil, 1); run("basic from only (to model)", a, @"opacity", 0, 1, 0.25); }
		{ CABasicAnimation *a = basic(@"opacity", nil, nil, 1); a.byValue = NUM(-0.5); run("basic by only", a, @"opacity", 0, 1, 0.25); }
		{ CABasicAnimation *a = basic(@"position.x", NUM(0), NUM(100), 1); a.additive = YES; run("basic additive position.x", a, @"position", 0, 1, 0.25); }
		{ CABasicAnimation *a = basic(@"position.x", NUM(0), NUM(100), 1); a.additive = YES; a.cumulative = YES; a.repeatCount = 3; run("basic cumulative repeat 3", a, @"position", 0, 3, 0.25); }
		/* timing */
		{ CABasicAnimation *a = basic(@"opacity", NUM(0), NUM(1), 1); a.repeatCount = 2.5; run("timing repeatCount 2.5", a, @"opacity", 0, 3, 0.25); }
		{ CABasicAnimation *a = basic(@"opacity", NUM(0), NUM(1), 1); a.autoreverses = YES; a.repeatCount = 2; run("timing autoreverses repeat 2", a, @"opacity", 0, 4, 0.25); }
		{ CABasicAnimation *a = basic(@"opacity", NUM(0), NUM(1), 1); a.repeatDuration = 2.5; run("timing repeatDuration 2.5", a, @"opacity", 0, 3, 0.25); }
		{ CABasicAnimation *a = basic(@"opacity", NUM(0), NUM(1), 1); a.timeOffset = 0.5; run("timing timeOffset .5", a, @"opacity", 0, 1.5, 0.25); }
		{ CABasicAnimation *a = basic(@"opacity", NUM(0), NUM(1), 1); a.beginTime = 0.5; a.fillMode = kCAFillModeBackwards; run("timing beginTime .5 backwards", a, @"opacity", 0, 2, 0.25); }
		{ CABasicAnimation *a = basic(@"opacity", NUM(0.3), NUM(0.8), 1); a.fillMode = kCAFillModeRemoved; run("timing fill removed", a, @"opacity", -0.5, 2, 0.25); }
		{ CABasicAnimation *a = basic(@"opacity", NUM(0.3), NUM(0.8), 1); a.fillMode = kCAFillModeForwards; run("timing fill forwards", a, @"opacity", -0.5, 2, 0.25); }
		{ CABasicAnimation *a = basic(@"opacity", NUM(0.3), NUM(0.8), 1); a.fillMode = kCAFillModeBackwards; run("timing fill backwards", a, @"opacity", -0.5, 2, 0.25); }
		/* keyframes */
		NSArray *vals = @[NUM(0), NUM(1), NUM(0.25), NUM(0.75)];
		for (NSString *m in @[kCAAnimationLinear, kCAAnimationDiscrete, kCAAnimationPaced, kCAAnimationCubic, kCAAnimationCubicPaced]) {
			CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"opacity"]; k.values = vals; k.duration = 1; k.calculationMode = m; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO;
			run([[NSString stringWithFormat:@"keyframe opacity %@", m] UTF8String], k, @"opacity", 0, 1, 0.0625);
		}
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"opacity"]; k.values = vals; k.keyTimes = @[@0, @0.2, @0.5, @1]; k.duration = 1; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO;
		  run("keyframe keyTimes", k, @"opacity", 0, 1, 0.0625); }
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"opacity"]; k.values = vals; k.timingFunctions = @[tf(kCAMediaTimingFunctionEaseIn), tf(kCAMediaTimingFunctionEaseOut), tf(kCAMediaTimingFunctionEaseInEaseOut)]; k.duration = 1; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO;
		  run("keyframe timingFunctions", k, @"opacity", 0, 1, 0.0625); }
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"position"]; k.values = @[PT(0, 0), PT(100, 0), PT(100, 100), PT(0, 100)]; k.duration = 1; k.calculationMode = kCAAnimationPaced; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO;
		  run("keyframe position paced", k, @"position", 0, 1, 0.0625); }
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"position"]; CGMutablePathRef p = CGPathCreateMutable(); CGPathMoveToPoint(p, NULL, 0, 0); CGPathAddCurveToPoint(p, NULL, 50, 0, 100, 50, 100, 100); CGPathAddLineToPoint(p, NULL, 0, 100);
		  k.path = p; k.duration = 1; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO; run("keyframe path position", k, @"position", 0, 1, 0.0625); }
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"position"]; CGMutablePathRef p = CGPathCreateMutable(); CGPathMoveToPoint(p, NULL, 0, 0); CGPathAddCurveToPoint(p, NULL, 50, 0, 100, 50, 100, 100);
		  k.path = p; k.rotationMode = kCAAnimationRotateAuto; k.duration = 1; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO; run("keyframe path rotateAuto", k, @"transform", 0, 1, 0.125); }
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"transform.rotation.z"]; k.values = @[NUM(0), NUM(0.5), NUM(-0.5), NUM(0)]; k.duration = 1; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO;
		  run("keyframe rotation shake", k, @"transform", 0, 1, 0.125); }
		/* keyframes of other value types */
		{ CGColorRef c1 = CGColorCreateGenericRGB(1, 0, 0, 1), c2 = CGColorCreateGenericRGB(0, 1, 0, 0.5), c3 = CGColorCreateGenericRGB(0, 0, 1, 1);
		  for (NSString *m in @[kCAAnimationLinear, kCAAnimationDiscrete, kCAAnimationPaced, kCAAnimationCubic, kCAAnimationCubicPaced]) {
			CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"backgroundColor"]; k.values = @[(__bridge id)c1, (__bridge id)c2, (__bridge id)c3]; k.duration = 1; k.calculationMode = m; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO;
			run([[NSString stringWithFormat:@"keyframe color %@", m] UTF8String], k, @"backgroundColor", 0, 1, 0.125); } }
		for (NSString *m in @[kCAAnimationLinear, kCAAnimationPaced, kCAAnimationCubic, kCAAnimationDiscrete]) {
			CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"bounds"]; k.values = @[[NSValue valueWithRect:NSMakeRect(0, 0, 10, 10)], [NSValue valueWithRect:NSMakeRect(5, 5, 50, 20)], [NSValue valueWithRect:NSMakeRect(0, 0, 20, 80)]]; k.duration = 1; k.calculationMode = m; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO;
			run([[NSString stringWithFormat:@"keyframe bounds %@", m] UTF8String], k, @"bounds", 0, 1, 0.125); }
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"opacity"]; k.values = @[@0, @1, @0.25]; k.duration = 1; k.timingFunctions = @[tf(kCAMediaTimingFunctionEaseIn), tf(kCAMediaTimingFunctionEaseOut)]; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO; run("keyframe 3 values with 2 tfs", k, @"opacity", 0, 1, 0.0625); }
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"opacity"]; k.values = @[@0, @1, @0.25, @0.9]; k.keyTimes = @[@0, @0.1, @0.8, @1]; k.calculationMode = kCAAnimationCubic; k.duration = 1; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO; run("keyframe cubic keyTimes uneven", k, @"opacity", 0, 1, 0.0625); }
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"opacity"]; k.values = @[@0, @1, @0.25, @0.9]; k.tensionValues = @[@0.5, @0, @-0.5, @0]; k.continuityValues = @[@0, @0.5, @0, @-0.5]; k.biasValues = @[@0, @0, @0.5, @0]; k.calculationMode = kCAAnimationCubic; k.duration = 1; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO; run("keyframe cubic TCB", k, @"opacity", 0, 1, 0.0625); }
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"position"]; k.values = @[PT(0, 0), PT(100, 0), PT(100, 100)]; k.calculationMode = kCAAnimationCubic; k.duration = 1; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO; run("keyframe cubic points", k, @"position", 0, 1, 0.0625); }
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"position"]; CGMutablePathRef p = CGPathCreateMutable(); CGPathMoveToPoint(p, NULL, 0, 0); CGPathAddLineToPoint(p, NULL, 100, 0); CGPathAddQuadCurveToPoint(p, NULL, 100, 100, 0, 100);
		  k.path = p; k.calculationMode = kCAAnimationPaced; k.duration = 1; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO; run("keyframe path paced", k, @"position", 0, 1, 0.0625); }
		{ CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"position"]; CGMutablePathRef p = CGPathCreateMutable(); CGPathAddEllipseInRect(p, NULL, CGRectMake(0, 0, 100, 60));
		  k.path = p; k.rotationMode = kCAAnimationRotateAutoReverse; k.duration = 1; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO; run("keyframe path ellipse autoReverse position", k, @"position", 0, 1, 0.0625); run("keyframe path ellipse autoReverse transform", k, @"transform", 0, 1, 0.125); }
		for (int q = 0; q < 3; q++) { for (double amt = -0.5; amt <= 0.51; amt += 1.0) {
			CAKeyframeAnimation *k = [CAKeyframeAnimation animationWithKeyPath:@"opacity"]; k.values = @[@0, @1, @0.25, @0.9, @0.4]; k.calculationMode = kCAAnimationCubic; k.duration = 1; k.fillMode = kCAFillModeBoth; k.removedOnCompletion = NO;
			NSArray *arr = @[NUM(amt), NUM(amt), NUM(amt), NUM(amt), NUM(amt)];
			if (q == 0) k.tensionValues = arr; else if (q == 1) k.continuityValues = arr; else k.biasValues = arr;
			char nm[64]; snprintf(nm, sizeof nm, "tcb %s %g", q == 0 ? "tension" : (q == 1 ? "continuity" : "bias"), amt);
			run(nm, k, @"opacity", 0, 1, 0.0625); } }
		/* group */
		{ CAAnimationGroup *g = [CAAnimationGroup animation]; CABasicAnimation *x = basic(@"opacity", NUM(0), NUM(1), 1), *y = basic(@"position.x", NUM(0), NUM(100), 2);
		  g.animations = @[x, y]; g.duration = 2; g.fillMode = kCAFillModeBoth; g.removedOnCompletion = NO; run("group opacity+position.x", g, @"opacity", 0, 2, 0.25); run("group position", g, @"position", 0, 2, 0.5); }
		/* springs */
		struct { double m, k, c, v; } sp[] = { { 1, 100, 10, 0 }, { 1, 100, 5, 0 }, { 1, 200, 20, 0 }, { 2, 300, 15, 5 }, { 1, 1000, 100, 0 }, { 1, 100, 10, 20 }, { 3, 50, 30, -4 }, { 1, 400, 2, 0 }, { 1, 100, 200, 0 }, { 1, 170, 26, 0 } };
		for (int i = 0; i < (int)(sizeof sp / sizeof sp[0]); i++) {
			CASpringAnimation *s = [CASpringAnimation animationWithKeyPath:@"opacity"]; s.mass = sp[i].m; s.stiffness = sp[i].k; s.damping = sp[i].c; s.initialVelocity = sp[i].v;
			s.fromValue = NUM(0); s.toValue = NUM(1); s.duration = s.settlingDuration; s.fillMode = kCAFillModeBoth; s.removedOnCompletion = NO;
			char nm[128]; snprintf(nm, sizeof nm, "spring m=%g k=%g c=%g v0=%g settling=%.9g", sp[i].m, sp[i].k, sp[i].c, sp[i].v, s.settlingDuration);
			run(nm, s, @"opacity", 0, s.duration, s.duration / 40);
		}
		{ CASpringAnimation *s = [CASpringAnimation animationWithKeyPath:@"position.x"]; s.fromValue = NUM(0); s.toValue = NUM(300); s.stiffness = 180; s.damping = 12; s.duration = 1.0; s.fillMode = kCAFillModeBoth; s.removedOnCompletion = NO; s.additive = NO;
		  run("spring position.x truncated duration 1.0", s, @"position", 0, 1.2, 0.05); }
	}
	return 0;
}
