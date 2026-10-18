/* Default values of every public property of the layer and animation classes (golden: the real QuartzCore). */
#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
static void fmtv(NSMutableString *s, id v)
{
	if (!v) { [s appendString:@"nil"]; return; }
	if ([v isKindOfClass:[NSNumber class]]) { [s appendFormat:@"%.9g", [v doubleValue]]; return; }
	if ([v isKindOfClass:[NSString class]]) { [s appendFormat:@"\"%@\"", v]; return; }
	if (CFGetTypeID((__bridge CFTypeRef)v) == CGColorGetTypeID()) {
		CGColorRef c = (__bridge CGColorRef)v; size_t n = CGColorGetNumberOfComponents(c); const CGFloat *p = CGColorGetComponents(c);
		[s appendString:@"color("]; for (size_t i = 0; i < n; i++) [s appendFormat:@"%s%.6g", i ? "," : "", p[i]]; [s appendString:@")"]; return;
	}
	if ([v isKindOfClass:[NSValue class]]) {
		const char *t = [v objCType]; double b[32] = { 0 }; [v getValue:b]; size_t sz; NSGetSizeAndAlignment(t, &sz, NULL);
		[s appendString:@"<"]; for (size_t i = 0; i < sz / 8; i++) [s appendFormat:@"%s%.9g", i ? " " : "", b[i]]; [s appendString:@">"]; return;
	}
	[s appendFormat:@"%@", [v description]];
}
static void dump(Class c, id obj)
{
	printf("## %s\n", class_getName(c));
	unsigned n; objc_property_t *ps = class_copyPropertyList(c, &n);
	NSMutableArray *names = [NSMutableArray array];
	for (unsigned i = 0; i < n; i++) [names addObject:[NSString stringWithUTF8String:property_getName(ps[i])]];
	free(ps);
	[names sortUsingSelector:@selector(compare:)];
	for (NSString *k in names) {
		if ([k isEqualToString:@"delegate"] || [k isEqualToString:@"hash"] || [k isEqualToString:@"description"] || [k isEqualToString:@"debugDescription"] || [k isEqualToString:@"superclass"]) continue;
		NSMutableString *s = [NSMutableString string];
		@try { fmtv(s, [obj valueForKey:k]); } @catch (id e) { [s appendString:@"<exception>"]; }
		printf("%s = %s\n", [k UTF8String], [s UTF8String]);
	}
}
int main(void)
{
	@autoreleasepool {
		dump([CALayer class], [CALayer layer]);
		dump([CAShapeLayer class], [CAShapeLayer layer]);
		dump([CATextLayer class], [CATextLayer layer]);
		dump([CAGradientLayer class], [CAGradientLayer layer]);
		dump([CAReplicatorLayer class], [CAReplicatorLayer layer]);
		dump([CAScrollLayer class], [CAScrollLayer layer]);
		dump([CATiledLayer class], [CATiledLayer layer]);
		dump([CAEmitterLayer class], [CAEmitterLayer layer]);
		dump([CAEmitterCell class], [CAEmitterCell emitterCell]);
		dump([CAAnimation class], [CAAnimation animation]);
		dump([CAPropertyAnimation class], [CAPropertyAnimation animationWithKeyPath:@"x"]);
		dump([CABasicAnimation class], [CABasicAnimation animation]);
		dump([CAKeyframeAnimation class], [CAKeyframeAnimation animation]);
		dump([CASpringAnimation class], [CASpringAnimation animation]);
		dump([CATransition class], [CATransition animation]);
		dump([CAAnimationGroup class], [CAAnimationGroup animation]);
	}
	return 0;
}
