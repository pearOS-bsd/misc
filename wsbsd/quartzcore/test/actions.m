/* Actions: what each property change adds to a layer (implicit animations): the same source is built against the real QuartzCore (make actions) and against this implementation (make check-actions); the printed values must be identical.
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


static NSString *describe(CALayer *l)
{
	NSArray *keys = [[l animationKeys] sortedArrayUsingSelector:@selector(compare:)];
	if (!keys.count) return @"none";
	NSMutableString *o = [NSMutableString string];
	for (NSString *k in keys) {
		CAAnimation *a = [l animationForKey:k]; float v1[2] = { 0, 0 }, v2[2] = { 0, 0 };
		[a.timingFunction getControlPointAtIndex:1 values:v1]; [a.timingFunction getControlPointAtIndex:2 values:v2];
		[o appendFormat:@"[%s %s dur=%g begin=%g speed=%g fill=%s rm=%d tf=%g,%g,%g,%g", [k UTF8String], [NSStringFromClass([a class]) UTF8String], a.duration, a.beginTime, a.speed, [a.fillMode UTF8String], a.removedOnCompletion, v1[0], v1[1], v2[0], v2[1]];
		if ([a isKindOfClass:[CABasicAnimation class]]) { NSMutableString *f = [NSMutableString string]; fmtv(f, ((CABasicAnimation *)a).fromValue); NSMutableString *t = [NSMutableString string]; fmtv(t, ((CABasicAnimation *)a).toValue); [o appendFormat:@" from=%@ to=%@ add=%d", f, t, ((CAPropertyAnimation *)a).additive]; }
		if ([a isKindOfClass:[CATransition class]]) { CATransition *t = (CATransition *)a; [o appendFormat:@" type=%@ sub=%@ p=%g..%g", t.type, t.subtype, t.startProgress, t.endProgress]; }
		[o appendString:@"]"];
	}
	return o;
}
#define T(name, expr) do { expr; printf("%-34s %s\n", name, [describe(L) UTF8String]); [L removeAllAnimations]; } while (0)
static CGColorRef C(double r, double g, double b) { return CGColorCreateGenericRGB(r, g, b, 1); }
int main(void)
{
	setvbuf(stdout, NULL, _IONBF, 0);
	@autoreleasepool {
		setup();
		[CATransaction begin]; [CATransaction setDisableActions:YES]; L.backgroundColor = C(1, 1, 1); L.shadowColor = C(0, 0, 0); L.borderColor = C(1, 1, 1); [CATransaction commit]; [CATransaction flush]; [L removeAllAnimations];
		T("bounds", L.bounds = CGRectMake(0, 0, 5, 5)); T("position", L.position = CGPointMake(1, 1)); T("zPosition", L.zPosition = 3); T("anchorPoint", L.anchorPoint = CGPointMake(.2, .2));
		T("transform", L.transform = CATransform3DMakeScale(2, 2, 1)); T("frame", L.frame = CGRectMake(5, 5, 50, 50)); T("hidden", L.hidden = YES); T("unhidden", L.hidden = NO);
		T("opacity", L.opacity = 0.3); T("backgroundColor", L.backgroundColor = C(0, 0, 1)); T("cornerRadius", L.cornerRadius = 5); T("masksToBounds", L.masksToBounds = YES);
		T("shadowOpacity", L.shadowOpacity = 0.5); T("shadowOffset", L.shadowOffset = CGSizeMake(3, 3)); T("shadowRadius", L.shadowRadius = 9); T("shadowColor", L.shadowColor = C(1, 0, 0));
		T("borderWidth", L.borderWidth = 2); T("borderColor", L.borderColor = C(0, 1, 0)); T("contents", L.contents = (__bridge id)C(1, 0, 0)); T("contentsRect", L.contentsRect = CGRectMake(0, 0, .5, .5));
		T("name", L.name = @"n"); T("sublayerTransform", L.sublayerTransform = CATransform3DMakeScale(2, 2, 1)); T("doubleSided", L.doubleSided = NO); T("opaque", L.opaque = YES);
		T("maskedCorners", L.maskedCorners = 3); T("filters", L.filters = @[]); T("mask", L.mask = [CALayer layer]);
		CALayer *s = [CALayer layer];
		T("addSublayer", [L addSublayer:s]); T("removeFromSuperlayer", [s removeFromSuperlayer]);
		/* transactions */
		[CATransaction begin]; [CATransaction setAnimationDuration:2]; T("txn dur 2: opacity", L.opacity = 0.9); [CATransaction commit];
		[CATransaction begin]; [CATransaction setAnimationTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]]; T("txn easeIn: position", L.position = CGPointMake(7, 7)); [CATransaction commit];
		[CATransaction begin]; [CATransaction setDisableActions:YES]; T("txn disabled: opacity", L.opacity = 0.1); [CATransaction commit];
		[CATransaction begin]; [CATransaction setAnimationDuration:3]; [CATransaction begin]; T("nested inherits dur 3", L.opacity = 0.7); [CATransaction setAnimationDuration:1]; T("nested dur 1", L.opacity = 0.6); [CATransaction commit]; T("outer again", L.opacity = 0.65); [CATransaction commit];
		[CATransaction begin]; [CATransaction setAnimationDuration:0]; T("txn dur 0", L.opacity = 0.2); [CATransaction commit];
		printf("txn defaults: dur=%g tf=%d disable=%d\n", [CATransaction animationDuration], [CATransaction animationTimingFunction] != nil, [CATransaction disableActions]);
		/* delegate and actions dictionary */
		L.actions = @{ @"opacity": [NSNull null] }; T("actions null: opacity", L.opacity = 0.5); T("actions null: position", L.position = CGPointMake(9, 9));
		CABasicAnimation *custom = [CABasicAnimation animationWithKeyPath:@"position"]; custom.duration = 5; L.actions = @{ @"position": custom }; T("actions custom: position", L.position = CGPointMake(11, 11)); L.actions = nil;
		/* presentation layer value as the start of the next animation */
		{ [CATransaction begin]; [CATransaction setAnimationDuration:1]; L.opacity = 1; [CATransaction commit]; L.opacity = 0.2; printf("%-34s %s\n", "second change keeps from=pres", [describe(L) UTF8String]); [L removeAllAnimations]; }
		/* a layer that is not in a rendered tree animates nothing */
		{ CALayer *free = [CALayer layer]; free.opacity = 0.3; free.position = CGPointMake(3, 3); printf("%-34s %s\n", "detached layer", [describe(free) UTF8String]); printf("pres of detached: %d\n", [free presentationLayer] != nil); }
		/* add/replace/remove animation keys */
		{ CABasicAnimation *a = [CABasicAnimation animationWithKeyPath:@"opacity"]; a.duration = 1; [L addAnimation:a forKey:@"x"]; [L addAnimation:a forKey:@"y"]; [L addAnimation:a forKey:nil]; printf("keys: %s\n", [[[[L animationKeys] sortedArrayUsingSelector:@selector(compare:)] componentsJoinedByString:@","] UTF8String]); [L removeAnimationForKey:@"x"]; printf("after remove x: %d\n", (int)[L animationKeys].count); [L removeAllAnimations]; printf("after remove all: %d\n", (int)[L animationKeys].count); }
	}
	return 0;
}
