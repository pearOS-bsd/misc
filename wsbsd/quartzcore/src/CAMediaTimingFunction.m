#import "CALayerPrivate.h"
NSString *const kCAMediaTimingFunctionLinear = @"linear";
NSString *const kCAMediaTimingFunctionEaseIn = @"easeIn";
NSString *const kCAMediaTimingFunctionEaseOut = @"easeOut";
NSString *const kCAMediaTimingFunctionEaseInEaseOut = @"easeInEaseOut";
NSString *const kCAMediaTimingFunctionDefault = @"default";

@implementation CAMediaTimingFunction
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)functionWithName:(NSString *)name
{
	static NSDictionary *table;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		table = @{ kCAMediaTimingFunctionLinear: [[CAMediaTimingFunction alloc] initWithControlPoints:0 :0 :1 :1],
		           kCAMediaTimingFunctionEaseIn: [[CAMediaTimingFunction alloc] initWithControlPoints:0.42f :0 :1 :1],
		           kCAMediaTimingFunctionEaseOut: [[CAMediaTimingFunction alloc] initWithControlPoints:0 :0 :0.58f :1],
		           kCAMediaTimingFunctionEaseInEaseOut: [[CAMediaTimingFunction alloc] initWithControlPoints:0.42f :0 :0.58f :1],
		           kCAMediaTimingFunctionDefault: [[CAMediaTimingFunction alloc] initWithControlPoints:0.25f :0.1f :0.25f :1] };
	});
	return table[name];
}
+ (instancetype)functionWithControlPoints:(float)a :(float)b :(float)c :(float)d { return [[self alloc] initWithControlPoints:a :b :c :d]; }
- (instancetype)initWithControlPoints:(float)a :(float)b :(float)c :(float)d { if ((self = [super init])) { _c[0] = a; _c[1] = b; _c[2] = c; _c[3] = d; } return self; }
- (void)getControlPointAtIndex:(size_t)idx values:(float *)p
{
	switch (idx) { case 0: p[0] = 0; p[1] = 0; break; case 1: p[0] = _c[0]; p[1] = _c[1]; break; case 2: p[0] = _c[2]; p[1] = _c[3]; break; default: p[0] = 1; p[1] = 1; }
}
- (float)_solve:(float)x { return CAMediaTimingFunctionSolve(_c, x); }
- (float)_solveForInput:(float)x { return CAMediaTimingFunctionSolve(_c, x); }
- (void)encodeWithCoder:(NSCoder *)c { for (int i = 0; i < 4; i++) [c encodeFloat:_c[i] forKey:[NSString stringWithFormat:@"c%d", i]]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithControlPoints:[c decodeFloatForKey:@"c0"] :[c decodeFloatForKey:@"c1"] :[c decodeFloatForKey:@"c2"] :[c decodeFloatForKey:@"c3"]]; }
@end

NSString *const kCAValueFunctionRotateX = @"rotateX";
NSString *const kCAValueFunctionRotateY = @"rotateY";
NSString *const kCAValueFunctionRotateZ = @"rotateZ";
NSString *const kCAValueFunctionScale = @"scale";
NSString *const kCAValueFunctionScaleX = @"scaleX";
NSString *const kCAValueFunctionScaleY = @"scaleY";
NSString *const kCAValueFunctionScaleZ = @"scaleZ";
NSString *const kCAValueFunctionTranslate = @"translate";
NSString *const kCAValueFunctionTranslateX = @"translateX";
NSString *const kCAValueFunctionTranslateY = @"translateY";
NSString *const kCAValueFunctionTranslateZ = @"translateZ";

@implementation CAValueFunction
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)functionWithName:(NSString *)name
{
	static NSArray *names; if (!names) names = @[@"rotateX", @"rotateY", @"rotateZ", @"scale", @"scaleX", @"scaleY", @"scaleZ", @"translate", @"translateX", @"translateY", @"translateZ"];
	if (![names containsObject:name]) return nil;
	CAValueFunction *f = [[self alloc] init]; f->_string = [name copy]; return f;
}
- (NSString *)name { return _string; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_string forKey:@"name"]; }
- (instancetype)initWithCoder:(NSCoder *)c { self = [super init]; _string = [c decodeObjectForKey:@"name"]; return self; }
@end

id CAValueApplyFunction(id fn, id value, id anim, id layer)
{
	NSString *n = [(CAValueFunction *)fn name]; double v = [value doubleValue];
	CATransform3D t;
	if ([n isEqualToString:@"rotateX"]) t = CATransform3DMakeRotation(v, 1, 0, 0);
	else if ([n isEqualToString:@"rotateY"]) t = CATransform3DMakeRotation(v, 0, 1, 0);
	else if ([n isEqualToString:@"rotateZ"]) t = CATransform3DMakeRotation(v, 0, 0, 1);
	else if ([n isEqualToString:@"scale"]) t = CATransform3DMakeScale(v, v, v);
	else if ([n isEqualToString:@"scaleX"]) t = CATransform3DMakeScale(v, 1, 1);
	else if ([n isEqualToString:@"scaleY"]) t = CATransform3DMakeScale(1, v, 1);
	else if ([n isEqualToString:@"scaleZ"]) t = CATransform3DMakeScale(1, 1, v);
	else if ([n isEqualToString:@"translateX"]) t = CATransform3DMakeTranslation(v, 0, 0);
	else if ([n isEqualToString:@"translateY"]) t = CATransform3DMakeTranslation(0, v, 0);
	else if ([n isEqualToString:@"translateZ"]) t = CATransform3DMakeTranslation(0, 0, v);
	else if ([n isEqualToString:@"translate"]) { NSSize s = [value sizeValue]; t = CATransform3DMakeTranslation(s.width, s.height, 0); }
	else return value;
	return [NSValue valueWithCATransform3D:t];
}
