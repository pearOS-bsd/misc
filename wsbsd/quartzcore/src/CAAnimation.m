/* The animation classes. An animation does not change a layer by itself: the layer applies it, at the time of the frame, to its presentation layer (-applyForTime:presentationObject:modelObject:). */
#import "CAInternal.h"
#import "CALayerPrivate.h"

NSString *const kCAAnimationLinear = @"linear";
NSString *const kCAAnimationDiscrete = @"discrete";
NSString *const kCAAnimationPaced = @"paced";
NSString *const kCAAnimationCubic = @"cubic";
NSString *const kCAAnimationCubicPaced = @"cubicPaced";
NSString *const kCAAnimationRotateAuto = @"auto";
NSString *const kCAAnimationRotateAutoReverse = @"autoReverse";
NSString *const kCATransitionFade = @"fade";
NSString *const kCATransitionMoveIn = @"moveIn";
NSString *const kCATransitionPush = @"push";
NSString *const kCATransitionReveal = @"reveal";
NSString *const kCATransitionFromRight = @"fromRight";
NSString *const kCATransitionFromLeft = @"fromLeft";
NSString *const kCATransitionFromTop = @"fromTop";
NSString *const kCATransitionFromBottom = @"fromBottom";
NSString *const kCAFillModeForwards = @"forwards";
NSString *const kCAFillModeBackwards = @"backwards";
NSString *const kCAFillModeBoth = @"both";
NSString *const kCAFillModeRemoved = @"removed";

/* the time of the animation inside its layer's time, with the timing function applied; false when the animation is not active at that time */
BOOL CAMapAnimationTime(CAAnimation *a, double *t, int *iteration)
{
	CATiming tm;
	if (CAAnimationTiming(a, &tm)) {
		if (!CATimingMapParentToActive(&tm, t, NULL)) return NO;
		if (iteration) {
			double cycle = tm.autoreverses ? tm.duration + tm.duration : tm.duration;
			*iteration = fabs(cycle) <= DBL_MAX ? (int)floor(*t / cycle) : 0;
		}
		CATimingMapActiveToLocal(&tm, t, NULL);
		*t = *t / tm.duration;
	} else if (iteration) *iteration = 0;
	CAMediaTimingFunction *f = a.timingFunction;
	if (f) *t = (double)[f _solve:(float)*t];
	return YES;
}

@implementation CAAnimation
{
	@public
	CFTimeInterval _beginTime, _duration, _timeOffset, _repeatDuration;
	float _speed, _repeatCount;
	BOOL _autoreverses, _removedOnCompletion, _enabled;
	NSString *_fillMode;
	CAMediaTimingFunction *_timingFunction;
	__weak id _delegate;
	CFTimeInterval _addedAt;                 /* layer time at which a beginTime of 0 means "now" */
	BOOL _hasAddedAt;
}
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)animation { return [[self alloc] init]; }
+ (id)defaultValueForKey:(NSString *)key { return nil; }
- (BOOL)shouldArchiveValueForKey:(NSString *)key { return YES; }
- (instancetype)init
{
	if ((self = [super init])) { _speed = 1; _removedOnCompletion = YES; _enabled = YES; _fillMode = @"removed"; }
	return self;
}
- (id)copyWithZone:(NSZone *)z
{
	CAAnimation *c = [[[self class] allocWithZone:z] init];
	c->_beginTime = _beginTime; c->_duration = _duration; c->_timeOffset = _timeOffset; c->_repeatDuration = _repeatDuration; c->_speed = _speed; c->_repeatCount = _repeatCount;
	c->_autoreverses = _autoreverses; c->_removedOnCompletion = _removedOnCompletion; c->_enabled = _enabled; c->_fillMode = [_fillMode copy]; c->_timingFunction = _timingFunction; c->_delegate = _delegate;
	c->_addedAt = _addedAt; c->_hasAddedAt = _hasAddedAt;
	[self _copyInto:c];
	return c;
}
- (void)_copyInto:(CAAnimation *)c {}
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (CFTimeInterval)beginTime { return _beginTime; }
- (void)setBeginTime:(CFTimeInterval)v { _beginTime = v; }
- (CFTimeInterval)duration { return _duration; }
- (void)setDuration:(CFTimeInterval)v { _duration = v; }
- (float)speed { return _speed; }
- (void)setSpeed:(float)v { _speed = v; }
- (CFTimeInterval)timeOffset { return _timeOffset; }
- (void)setTimeOffset:(CFTimeInterval)v { _timeOffset = v; }
- (float)repeatCount { return _repeatCount; }
- (void)setRepeatCount:(float)v { _repeatCount = v; }
- (CFTimeInterval)repeatDuration { return _repeatDuration; }
- (void)setRepeatDuration:(CFTimeInterval)v { _repeatDuration = v; }
- (BOOL)autoreverses { return _autoreverses; }
- (void)setAutoreverses:(BOOL)v { _autoreverses = v; }
- (NSString *)fillMode { return _fillMode; }
- (void)setFillMode:(NSString *)v { _fillMode = [v copy]; }
- (CAMediaTimingFunction *)timingFunction { return _timingFunction; }
- (void)setTimingFunction:(CAMediaTimingFunction *)v { _timingFunction = v; }
- (id)delegate { return _delegate; }
- (void)setDelegate:(id)v { _delegate = v; }
- (BOOL)isRemovedOnCompletion { return _removedOnCompletion; }
- (void)setRemovedOnCompletion:(BOOL)v { _removedOnCompletion = v; }
- (BOOL)isEnabled { return _enabled; }
- (void)setEnabled:(BOOL)v { _enabled = v; }
- (void)runActionForKey:(NSString *)event object:(id)anObject arguments:(NSDictionary *)dict { [(CALayer *)anObject addAnimation:self forKey:event]; }
- (void)applyForTime:(CFTimeInterval)t presentationObject:(id)pres modelObject:(id)model {}
- (float)_solveTiming:(float)x { return x; }
- (void)setDefaultDuration:(CFTimeInterval)d { if (_duration <= 0) _duration = d; }
- (CFTimeInterval)_addedAt { return _addedAt; }
- (BOOL)_hasAddedAt { return _hasAddedAt; }
- (void)_setAddedAt:(CFTimeInterval)t { _addedAt = t; _hasAddedAt = YES; }
- (BOOL)_hasStarted { return YES; }
@end

/* the timing of an animation as the layer sees it: a begin time of 0 means the moment the animation was added */
bool CAAnimationTiming(CAAnimation *a, CATiming *t)
{
	if (!CATimingFromObject(a, t)) {
		/* nothing special about the timing, yet an animation with duration 0 is not infinite: it is covered below */
		return false;
	}
	if (a->_hasAddedAt && t->begin == 0) { t->begin = a->_addedAt; t->endValid = 0; }
	return true;
}

@implementation CAPropertyAnimation
{
	NSString *_keyPath; BOOL _additive, _cumulative; CAValueFunction *_valueFunction;
}
+ (instancetype)animationWithKeyPath:(NSString *)path { CAPropertyAnimation *a = [self animation]; a->_keyPath = [path copy]; return a; }
- (void)_copyInto:(CAAnimation *)c { CAPropertyAnimation *p = (CAPropertyAnimation *)c; p->_keyPath = [_keyPath copy]; p->_additive = _additive; p->_cumulative = _cumulative; p->_valueFunction = _valueFunction; }
- (NSString *)keyPath { return _keyPath; }
- (void)setKeyPath:(NSString *)v { _keyPath = [v copy]; }
- (BOOL)isAdditive { return _additive; }
- (void)setAdditive:(BOOL)v { _additive = v; }
- (BOOL)isCumulative { return _cumulative; }
- (void)setCumulative:(BOOL)v { _cumulative = v; }
- (CAValueFunction *)valueFunction { return _valueFunction; }
- (void)setValueFunction:(CAValueFunction *)v { _valueFunction = v; }
@end

@implementation CABasicAnimation
{
	id _from, _to, _by;
}
- (void)_copyInto:(CAAnimation *)c { [super _copyInto:c]; CABasicAnimation *b = (CABasicAnimation *)c; b->_from = _from; b->_to = _to; b->_by = _by; }
- (id)fromValue { return _from; }
- (void)setFromValue:(id)v { _from = v; }
- (id)toValue { return _to; }
- (void)setToValue:(id)v { _to = v; }
- (id)byValue { return _by; }
- (void)setByValue:(id)v { _by = v; }
- (double)_timeFunction:(double)t { return t; }

- (void)applyForTime:(CFTimeInterval)time presentationObject:(id)pres modelObject:(id)model
{
	if (![self isEnabled]) return;
	NSString *kp = [self keyPath]; if (!kp) return;
	double t = time; int iteration = 0;
	if (!CAMapAnimationTime(self, &t, &iteration)) return;
	id from = _from, to = _to, by = _by;
	if (from && to) {}
	else if (from && by) to = CAValueAdd(from, by, 1);
	else if (to && by) from = CAValueAdd(to, by, -1);
	else if (from) to = [model valueForKeyPath:kp];
	else if (to) from = [pres valueForKeyPath:kp];
	else if (by) { from = [pres valueForKeyPath:kp]; if (from) to = CAValueAdd(from, by, 1); }
	else return;
	if (!from || !to) return;
	id value;
	if (t <= 0) value = from;
	else if (t >= 1) value = to;
	else {
		t = [self _timeFunction:t];
		value = CAValueInterpolate(from, to, (float)t);
		if ([self _roundsToInteger]) value = @((double)llround([value doubleValue]));
	}
	if ([self isCumulative] && iteration) value = CAValueAdd(value, [self autoreverses] ? from : to, iteration);
	if ([self valueFunction]) value = CAValueApplyFunction([self valueFunction], value, self, pres);
	if ([self isAdditive]) value = CAValueAdd([pres valueForKeyPath:kp], value, 1);
	[pres setValue:value forKeyPath:kp];
}
- (BOOL)_roundsToInteger { return NO; }
@end

/* the value of a from/to animation at the time t seconds after it began: what the animation puts on a layer, without a layer (for AppKit's animator proxies and the like) */
id CABasicAnimationValueAtTime(CABasicAnimation *a, CFTimeInterval t)
{
	double tt = t; int it = 0;
	if (!CAMapAnimationTime(a, &tt, &it)) return nil;
	id from = [a fromValue], to = [a toValue];
	if (!from || !to) return nil;
	if (tt <= 0) return from;
	if (tt >= 1) return to;
	tt = [a _timeFunction:tt];
	return CAValueInterpolate(from, to, (float)tt);
}


/* ---- springs --------------------------------------------------------------------------------------------------------------------------------------------------------- */
typedef struct { double w0, zeta, wd, a, b; BOOL over; } SpringState;
static void spring_update(SpringState *s, double m, double k, double c, double v0, BOOL allowsOver)
{
	s->w0 = sqrt(k / m);
	s->zeta = c / (2 * sqrt(k * m));
	s->over = allowsOver;
	double zeta = s->zeta, w0 = s->w0;
	if (zeta < 1) {
		s->wd = sqrt(1 - zeta * zeta) * w0; s->a = 1; s->b = (zeta * w0 - v0) / s->wd;
	} else if (allowsOver && zeta > 1) {
		double d = sqrt(zeta * zeta - 1) * w0, e = zeta * w0 + v0;
		s->wd = d; s->a = (e + d) / (d + d); s->b = (d - e) / (d + d);
	} else { s->wd = 0; s->a = 1; s->b = w0 - v0; }
}
static double spring_eval(const SpringState *s, double t)
{
	double zeta = s->zeta, w0 = s->w0;
	double x;
	if (zeta < 1) {
		double e = exp(-t * zeta * w0);
		x = e * (s->a * cos(s->wd * t) + s->b * sin(s->wd * t));
	} else if (zeta > 1 && s->over) {
		double zw = zeta * w0;
		x = s->a * exp(-t * (zw + s->wd)) + s->b * exp(t * (s->wd - zw));
	} else x = exp(-t * w0) * (s->b * t + s->a);
	return 1 - x;
}

@implementation CASpringAnimation
{
	CGFloat _mass, _stiffness, _damping, _velocity; BOOL _over;
}
- (instancetype)init { if ((self = [super init])) { _mass = 1; _stiffness = 100; _damping = 10; } return self; }
- (instancetype)initWithPerceptualDuration:(CFTimeInterval)d bounce:(CGFloat)bounce
{
	if ((self = [self init])) {
		double w = 2 * M_PI / d;
		_mass = 1; _stiffness = w * w;
		_damping = bounce >= 0 ? 4 * M_PI * (1 - bounce) / d : 4 * M_PI / (d * (1 + bounce));
	}
	return self;
}
- (void)_copyInto:(CAAnimation *)c { [super _copyInto:c]; CASpringAnimation *s = (CASpringAnimation *)c; s->_mass = _mass; s->_stiffness = _stiffness; s->_damping = _damping; s->_velocity = _velocity; s->_over = _over; }
- (CGFloat)mass { return _mass; }
- (void)setMass:(CGFloat)v { _mass = v; }
- (CGFloat)stiffness { return _stiffness; }
- (void)setStiffness:(CGFloat)v { _stiffness = v; }
- (CGFloat)damping { return _damping; }
- (void)setDamping:(CGFloat)v { _damping = v; }
- (CGFloat)initialVelocity { return _velocity; }
- (void)setInitialVelocity:(CGFloat)v { _velocity = v; }
- (BOOL)allowsOverdamping { return _over; }
- (void)setAllowsOverdamping:(BOOL)v { _over = v; }
- (double)_timeFunction:(double)t
{
	SpringState s; spring_update(&s, _mass, _stiffness, _damping, _velocity, _over);
	return spring_eval(&s, [self duration] * t);
}
- (CFTimeInterval)durationForEpsilon:(double)eps
{
	SpringState s; spring_update(&s, _mass, _stiffness, _damping, _velocity, _over);
	double d9;
	if (s.zeta == 0) d9 = INFINITY;
	else {
		double e = fmax(eps, 1e-6);
		if (s.zeta < 1) {
			double v = -log(e / (fabs(s.a) + fabs(s.b))) / (s.zeta * s.w0);
			d9 = fmax(v, 0.0);
		} else {
			double best = -1, minDev = INFINITY, t = 0; BOOL done = NO;
			for (;;) {
				double v = spring_eval(&s, t), dd = 1 - v;
				if (!(fabs(dd) <= DBL_MAX)) { best = 0; break; }
				double dev = fabs(dd);
				if (minDev >= e) { if (dev < minDev) { best = t; minDev = dev; } }
				else if (dev >= e) minDev = INFINITY;
				else if (t - best > 1) break;
				t += 0.1;
			}
			(void)done; d9 = best;
		}
	}
	float sp = [self speed];
	if (sp == 0) return FLT_MAX;
	return fmin(fabs(d9 / (double)sp), (double)FLT_MAX);
}
- (CFTimeInterval)settlingDuration { return [self durationForEpsilon:0.001]; }
- (CFTimeInterval)perceptualDuration { return 2 * M_PI / sqrt(_stiffness / _mass); }
- (CGFloat)bounce
{
	double w = 2 * M_PI / [self perceptualDuration], c = _damping, d = 2 * M_PI / w; (void)d;
	double dur = [self perceptualDuration];
	double b = 1 - c * dur / (4 * M_PI);
	if (b >= 0) return b;
	return 4 * M_PI / (dur * c) - 1;
}
@end

/* ---- keyframes ------------------------------------------------------------------------------------------------------------------------------------------------------ */
@implementation CAKeyframeAnimation
{
	NSArray *_values; CGPathRef _path; NSArray *_keyTimes, *_timingFunctions, *_tension, *_continuity, *_bias; NSString *_calc, *_rotation;
}
- (instancetype)init { if ((self = [super init])) _calc = @"linear"; return self; }
- (void)dealloc { if (_path) CGPathRelease(_path); }
- (void)_copyInto:(CAAnimation *)c
{
	[super _copyInto:c]; CAKeyframeAnimation *k = (CAKeyframeAnimation *)c;
	k->_values = _values; k->_path = _path ? CGPathRetain(_path) : NULL; k->_keyTimes = _keyTimes; k->_timingFunctions = _timingFunctions; k->_tension = _tension; k->_continuity = _continuity; k->_bias = _bias; k->_calc = _calc; k->_rotation = _rotation;
}
- (id)valueForKey:(NSString *)key { if ([key isEqualToString:@"path"]) return _path ? (__bridge id)_path : nil; return [super valueForKey:key]; }
- (NSArray *)values { return _values; }
- (void)setValues:(NSArray *)v { _values = [v copy]; }
- (CGPathRef)path { return _path; }
- (void)setPath:(CGPathRef)p { if (p) CGPathRetain(p); if (_path) CGPathRelease(_path); _path = p; }
- (NSArray *)keyTimes { return _keyTimes; }
- (void)setKeyTimes:(NSArray *)v { _keyTimes = [v copy]; }
- (NSArray *)timingFunctions { return _timingFunctions; }
- (void)setTimingFunctions:(NSArray *)v { _timingFunctions = [v copy]; }
- (NSString *)calculationMode { return _calc; }
- (void)setCalculationMode:(NSString *)v { _calc = [v copy]; }
- (NSArray *)tensionValues { return _tension; }
- (void)setTensionValues:(NSArray *)v { _tension = [v copy]; }
- (NSArray *)continuityValues { return _continuity; }
- (void)setContinuityValues:(NSArray *)v { _continuity = [v copy]; }
- (NSArray *)biasValues { return _bias; }
- (void)setBiasValues:(NSArray *)v { _bias = [v copy]; }
- (NSString *)rotationMode { return _rotation; }
- (void)setRotationMode:(NSString *)v { _rotation = [v copy]; }
- (void)applyForTime:(CFTimeInterval)time presentationObject:(id)pres modelObject:(id)model
{
	CAKeyframeApply(self, time, pres, model);
}
@end

@implementation CATransition
{
	NSString *_type, *_subtype; float _start, _end; id _filter;
}
- (instancetype)init { if ((self = [super init])) { _type = @"fade"; _end = 1; } return self; }
- (void)_copyInto:(CAAnimation *)c { CATransition *t = (CATransition *)c; t->_type = _type; t->_subtype = _subtype; t->_start = _start; t->_end = _end; t->_filter = _filter; }
- (NSString *)type { return _type; }
- (void)setType:(NSString *)v { _type = [v copy]; }
- (NSString *)subtype { return _subtype; }
- (void)setSubtype:(NSString *)v { _subtype = [v copy]; }
- (float)startProgress { return _start; }
- (void)setStartProgress:(float)v { _start = v; }
- (float)endProgress { return _end; }
- (void)setEndProgress:(float)v { _end = v; }
- (id)filter { return _filter; }
- (void)setFilter:(id)v { _filter = v; }
@end

@implementation CAAnimationGroup
{
	NSArray *_animations;
}
- (void)_copyInto:(CAAnimation *)c { ((CAAnimationGroup *)c)->_animations = [[NSArray alloc] initWithArray:_animations copyItems:YES]; }
- (void)setDefaultDuration:(CFTimeInterval)d
{
	if ([self duration] <= 0) [self setDuration:d];
	for (CAAnimation *a in _animations) [a setDefaultDuration:[self duration]];
}
- (NSArray *)animations { return _animations; }
- (void)setAnimations:(NSArray *)v { _animations = [v copy]; }
- (void)applyForTime:(CFTimeInterval)time presentationObject:(id)pres modelObject:(id)model
{
	if (![self isEnabled] || !_animations.count) return;
	double t = time;
	if (!CAMapAnimationTime(self, &t, NULL)) return;
	t = [self duration] * t;
	for (CAAnimation *a in _animations) [a applyForTime:t presentationObject:pres modelObject:model];
}
@end
