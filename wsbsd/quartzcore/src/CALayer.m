/* CALayer: model values, sublayers, geometry, actions, animations and the presentation layer. */
#import "CALayerPrivate.h"
#include <stddef.h>
#include <string.h>

NSString *const kCAGravityCenter = @"center"; NSString *const kCAGravityTop = @"top"; NSString *const kCAGravityBottom = @"bottom";
NSString *const kCAGravityLeft = @"left"; NSString *const kCAGravityRight = @"right"; NSString *const kCAGravityTopLeft = @"topLeft";
NSString *const kCAGravityTopRight = @"topRight"; NSString *const kCAGravityBottomLeft = @"bottomLeft"; NSString *const kCAGravityBottomRight = @"bottomRight";
NSString *const kCAGravityResize = @"resize"; NSString *const kCAGravityResizeAspect = @"resizeAspect"; NSString *const kCAGravityResizeAspectFill = @"resizeAspectFill";
NSString *const kCAContentsFormatRGBA8Uint = @"RGBA8"; NSString *const kCAContentsFormatRGBA16Float = @"RGBA16Float"; NSString *const kCAContentsFormatGray8Uint = @"Gray8"; NSString *const kCAContentsFormatAutomatic = @"automatic";
NSString *const kCAFilterNearest = @"nearest"; NSString *const kCAFilterLinear = @"linear"; NSString *const kCAFilterTrilinear = @"trilinear";
NSString *const kCACornerCurveCircular = @"circular"; NSString *const kCACornerCurveContinuous = @"continuous";
NSString *const kCAOnOrderIn = @"onOrderIn"; NSString *const kCAOnOrderOut = @"onOrderOut"; NSString *const kCATransition = @"transition";
NSString *const CAToneMapModeAutomatic = @"automatic"; NSString *const CAToneMapModeNever = @"never"; NSString *const CAToneMapModeIfSupported = @"ifSupported";
NSString *const CADynamicRangeAutomatic = @"automatic"; NSString *const CADynamicRangeStandard = @"standard"; NSString *const CADynamicRangeConstrainedHigh = @"constrainedHigh"; NSString *const CADynamicRangeHigh = @"high";
NSString *const kCAFillRuleNonZero = @"non-zero"; NSString *const kCAFillRuleEvenOdd = @"even-odd";
NSString *const kCALineJoinMiter = @"miter"; NSString *const kCALineJoinRound = @"round"; NSString *const kCALineJoinBevel = @"bevel";
NSString *const kCALineCapButt = @"butt"; NSString *const kCALineCapRound = @"round"; NSString *const kCALineCapSquare = @"square";
NSString *const kCATruncationNone = @"none"; NSString *const kCATruncationStart = @"start"; NSString *const kCATruncationEnd = @"end"; NSString *const kCATruncationMiddle = @"middle";
NSString *const kCAAlignmentNatural = @"natural"; NSString *const kCAAlignmentLeft = @"left"; NSString *const kCAAlignmentRight = @"right"; NSString *const kCAAlignmentCenter = @"center"; NSString *const kCAAlignmentJustified = @"justified";
NSString *const kCAGradientLayerAxial = @"axial"; NSString *const kCAGradientLayerRadial = @"radial"; NSString *const kCAGradientLayerConic = @"conic";
NSString *const kCAScrollNone = @"none"; NSString *const kCAScrollVertically = @"vertically"; NSString *const kCAScrollHorizontally = @"horizontally"; NSString *const kCAScrollBoth = @"both";
NSString *const kCAEmitterLayerPoint = @"point"; NSString *const kCAEmitterLayerLine = @"line"; NSString *const kCAEmitterLayerRectangle = @"rectangle"; NSString *const kCAEmitterLayerCuboid = @"cuboid";
NSString *const kCAEmitterLayerCircle = @"circle"; NSString *const kCAEmitterLayerSphere = @"sphere";
NSString *const kCAEmitterLayerPoints = @"points"; NSString *const kCAEmitterLayerOutline = @"outline"; NSString *const kCAEmitterLayerSurface = @"surface"; NSString *const kCAEmitterLayerVolume = @"volume";
NSString *const kCAEmitterLayerUnordered = @"unordered"; NSString *const kCAEmitterLayerOldestFirst = @"oldestFirst"; NSString *const kCAEmitterLayerOldestLast = @"oldestLast";
NSString *const kCAEmitterLayerBackToFront = @"backToFront"; NSString *const kCAEmitterLayerAdditive = @"additive";
const CAFrameRateRange CAFrameRateRangeDefault = { 0, 0, 0 };
CAFrameRateRange CAFrameRateRangeMake(float a, float b, float c) { CAFrameRateRange r = { a, b, c }; return r; }
bool CAFrameRateRangeIsEqualToRange(CAFrameRateRange a, CAFrameRateRange b) { return a.minimum == b.minimum && a.maximum == b.maximum && a.preferred == b.preferred; }

/* ---- the property table ------------------------------------------------------------------------------------------------------------------------------------------ */
typedef enum { CAT_F, CAT_D, CAT_B, CAT_U, CAT_UL, CAT_PT, CAT_SZ, CAT_RC, CAT_TF, CAT_COL, CAT_PATH, CAT_OBJ, CAT_STR, CAT_ARR } CAType;
enum { CAF_A = 1, CAF_T = 2, CAF_X = 4, CAF_G = 8, CAF_N = 16 };
typedef struct { const char *name; CAType type; size_t off; unsigned flags; const char *cls; } CAPropDesc;

static CGColorRef CALayerBlackColor(void) { static CGColorRef c; if (!c) { CGFloat v[4] = { 0, 0, 0, 1 }; CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); c = CGColorCreate(cs, v); CGColorSpaceRelease(cs); } return c; }
static CGColorRef CALayerWhiteColor(void) { static CGColorRef c; if (!c) { CGFloat v[4] = { 1, 1, 1, 1 }; CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); c = CGColorCreate(cs, v); CGColorSpaceRelease(cs); } return c; }

#include "CALayerProps.inc"

static int CAPropIndex(NSString *key)
{
	static NSDictionary *map;
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		NSMutableDictionary *m = [NSMutableDictionary dictionary];
		for (int i = 0; i < CAPropCount; i++) m[@(kCAProps[i].name)] = @(i);
		map = m;
	});
	NSNumber *n = map[key];
	return n ? [n intValue] : -1;
}

static id CABox(CAType t, const void *p)
{
	switch (t) {
	case CAT_F: return [NSNumber numberWithFloat:*(const float *)p];
	case CAT_D: return [NSNumber numberWithDouble:*(const CGFloat *)p];
	case CAT_B: return [NSNumber numberWithBool:*(const BOOL *)p];
	case CAT_U: return [NSNumber numberWithUnsignedInt:*(const unsigned *)p];
	case CAT_UL: return [NSNumber numberWithUnsignedLong:*(const NSUInteger *)p];
	case CAT_PT: return [NSValue valueWithBytes:p objCType:@encode(CGPoint)];
	case CAT_SZ: return [NSValue valueWithBytes:p objCType:@encode(CGSize)];
	case CAT_RC: return [NSValue valueWithBytes:p objCType:@encode(CGRect)];
	case CAT_TF: return [NSValue valueWithBytes:p objCType:@encode(CATransform3D)];
	case CAT_COL: { CGColorRef c = *(CGColorRef const *)p; return c ? (__bridge id)c : nil; }
	case CAT_PATH: { CGPathRef c = *(CGPathRef const *)p; return c ? (__bridge id)c : nil; }
	default: return *(__unsafe_unretained id const *)p;
	}
}
static BOOL CAUnbox(CAType t, id v, void *out)
{
	switch (t) {
	case CAT_F: if (![v respondsToSelector:@selector(floatValue)]) return NO; *(float *)out = [v floatValue]; return YES;
	case CAT_D: if (![v respondsToSelector:@selector(doubleValue)]) return NO; *(CGFloat *)out = [v doubleValue]; return YES;
	case CAT_B: if (![v respondsToSelector:@selector(boolValue)]) return NO; *(BOOL *)out = [v boolValue]; return YES;
	case CAT_U: if (![v respondsToSelector:@selector(unsignedIntValue)]) return NO; *(unsigned *)out = [v unsignedIntValue]; return YES;
	case CAT_UL: if (![v respondsToSelector:@selector(unsignedLongValue)]) return NO; *(NSUInteger *)out = [v unsignedLongValue]; return YES;
	case CAT_PT: case CAT_SZ: case CAT_RC: case CAT_TF:
		if (![v isKindOfClass:[NSValue class]]) return NO;
		{ size_t sz = t == CAT_PT || t == CAT_SZ ? 16 : (t == CAT_RC ? 32 : 128); [v getValue:out]; (void)sz; }
		return YES;
	default: return NO;
	}
}

static void CAStoreObject(__unsafe_unretained id *slot, id v) { id old = *slot; *slot = v ? (__bridge id)CFBridgingRetain(v) : nil; if (old) CFRelease((__bridge CFTypeRef)old); }
static void CAStoreCF(void **slot, void *v) { if (v) CFRetain(v); if (*slot) CFRelease(*slot); *slot = v; }

static BOOL CAEqualBytes(CAType t, const void *a, const void *b)
{
	switch (t) {
	case CAT_F: return *(const float *)a == *(const float *)b;
	case CAT_D: return *(const CGFloat *)a == *(const CGFloat *)b;
	case CAT_B: return *(const BOOL *)a == *(const BOOL *)b;
	case CAT_U: return *(const unsigned *)a == *(const unsigned *)b;
	case CAT_UL: return *(const NSUInteger *)a == *(const NSUInteger *)b;
	case CAT_PT: case CAT_SZ: return memcmp(a, b, 16) == 0;
	case CAT_RC: return memcmp(a, b, 32) == 0;
	case CAT_TF: return memcmp(a, b, 128) == 0;
	case CAT_COL: { CGColorRef x = *(CGColorRef const *)a, y = *(CGColorRef const *)b; return x == y || (x && y && CGColorEqualToColor(x, y)); }
	case CAT_PATH: return *(CGPathRef const *)a == *(CGPathRef const *)b;
	default: { id x = *(__unsafe_unretained id const *)a, y = *(__unsafe_unretained id const *)b; return x == y || [x isEqual:y]; }
	}
}

/* ---- layer ----------------------------------------------------------------------------------------------------------------------------------------------------------- */
@interface CALayerEntry : NSObject
{ @public
	NSString *key; CAAnimation *anim; BOOL started, finished;
}
@end
@implementation CALayerEntry @end

static NSHashTable *gAnimatedLayers, *gSnapshotLayers, *gContextRoots;
static void (^gChangeObserver)(CALayer *);
void CALayerSetChangeObserver(void (^obs)(CALayer *)) { gChangeObserver = [obs copy]; }
static inline void CANotify(CALayer *l) { if (gChangeObserver) gChangeObserver(l); }
static uint64_t gGeneration;

@implementation CALayer
{
	CALayerData d;
	__weak CALayer *_superlayer;
	NSMutableArray *_sublayers;
	NSMutableArray *_anims;                    /* CALayerEntry, in the order added */
	CALayer *_model;                           /* for a presentation layer */
	CALayer *_presentation;
	CFTimeInterval _presentationTime; uint64_t _presentationGen, _version;
	BOOL _isPresentation, _contextRoot, _needsLayout, _needsDisplay, _committed;
	CFTimeInterval _beginTime, _duration, _timeOffset, _repeatDuration;
	float _speed, _repeatCount;
	BOOL _autoreverses;
	NSString *_fillMode;
	NSDictionary *_actions;
	__weak id _delegate;
	id _layoutManager;
	CALayer *_mask;
	CALayer *_maskedLayer;
}
CA_ACCESSORS_CALayer

+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)layer { return [[self alloc] init]; }
- (instancetype)init
{
	if ((self = [super init])) {
		CALayerDataInit(&d);
		_speed = 1; _duration = INFINITY; _fillMode = @"removed";
	}
	return self;
}
- (instancetype)initWithLayer:(id)layer
{
	if ((self = [self init])) {
		CALayer *o = layer;
		if ([o isKindOfClass:[CALayer class]]) [self _copyPropertiesFrom:o];
	}
	return self;
}
- (void)_copyPropertiesFrom:(CALayer *)o
{
	for (int i = 0; i < CAPropCount; i++) {
		const CAPropDesc *p = &kCAProps[i];
		char *src = (char *)&o->d + p->off, *dst = (char *)&d + p->off;
		switch (p->type) {
		case CAT_COL: case CAT_PATH: CAStoreCF((void **)dst, *(void **)src); break;
		case CAT_OBJ: case CAT_STR: case CAT_ARR: CAStoreObject((__unsafe_unretained id *)(void *)dst, *(__unsafe_unretained id *)(void *)src); break;
		default: memcpy(dst, src, p->type == CAT_TF ? 128 : (p->type == CAT_RC ? 32 : (p->type == CAT_PT || p->type == CAT_SZ ? 16 : (p->type == CAT_D || p->type == CAT_UL ? 8 : 4))));
		}
	}
	_beginTime = o->_beginTime; _duration = o->_duration; _timeOffset = o->_timeOffset; _repeatDuration = o->_repeatDuration; _speed = o->_speed; _repeatCount = o->_repeatCount; _autoreverses = o->_autoreverses; _fillMode = o->_fillMode;
	_delegate = o->_delegate; _actions = o->_actions; _layoutManager = o->_layoutManager;
}
- (void)dealloc
{
	for (int i = 0; i < CAPropCount; i++) {
		const CAPropDesc *p = &kCAProps[i];
		char *dst = (char *)&d + p->off;
		switch (p->type) {
		case CAT_COL: case CAT_PATH: if (*(void **)dst) CFRelease(*(void **)dst); break;
		case CAT_OBJ: case CAT_STR: case CAT_ARR: if (*(__unsafe_unretained id *)(void *)dst) CFRelease((__bridge CFTypeRef)*(__unsafe_unretained id *)(void *)dst); break;
		default: break;
		}
	}
}
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
+ (id)defaultValueForKey:(NSString *)key { return nil; }
+ (BOOL)needsDisplayForKey:(NSString *)key { int i = CAPropIndex(key); return i >= 0 && (kCAProps[i].flags & CAF_X); }
- (BOOL)shouldArchiveValueForKey:(NSString *)key { return YES; }

- (BOOL)_isPresentation { return _isPresentation; }
- (BOOL)_inContext
{
	if (!_isPresentation && !_committed) return NO;           /* a layer is part of the rendered tree after its first commit */
	for (CALayer *l = self; l; l = l->_superlayer) if (l->_contextRoot || (l->_model && l->_model->_contextRoot)) return YES;
	return NO;
}
- (void)_markCommitted { _committed = YES; for (CALayer *s in _sublayers) [s _markCommitted]; [_mask _markCommitted]; }
- (void)_setContext:(BOOL)c { _contextRoot = c; if (c) { if (!gContextRoots) gContextRoots = [NSHashTable weakObjectsHashTable]; [gContextRoots addObject:self]; } }

/* ---- generic property access ------------------------------------------------------------------------------------------------------------------------------------- */
- (id)_boxedPropertyAtIndex:(int)i { return CABox(kCAProps[i].type, (char *)&d + kCAProps[i].off); }

static void CAGetProp(CALayer *l, int i, void *out)
{
	const CAPropDesc *p = &kCAProps[i]; const void *src = (char *)&l->d + p->off;
	size_t n = p->type == CAT_TF ? 128 : (p->type == CAT_RC ? 32 : (p->type == CAT_PT || p->type == CAT_SZ ? 16 : (p->type == CAT_D || p->type == CAT_UL || p->type == CAT_COL || p->type == CAT_PATH ? 8 : (p->type == CAT_B ? sizeof(BOOL) : 4))));
	memcpy(out, src, n);
}
static id CAGetObjProp(CALayer *l, int i) { return *(__unsafe_unretained id *)(void *)((char *)&l->d + kCAProps[i].off); }

/* the part of a change that is the same for every property: the actions, the bookkeeping */
- (void)_changeIndex:(int)i toBytes:(const void *)p isObject:(BOOL)isObj
{
	const CAPropDesc *pd = &kCAProps[i]; char *slot = (char *)&d + pd->off;
	if (!_isPresentation && !CAEqualBytes(pd->type, slot, p) ) { /* fall through to change */ }
	else if (!_isPresentation && CAEqualBytes(pd->type, slot, p)) return;
	id action = nil;
	if (!_isPresentation && ![CATransaction disableActions]) {
		NSString *key = @(pd->name);
		action = [self _actionForPropertyChange:key flags:pd->flags];
	}
	[self _storeAt:slot type:pd->type from:p];
	_version++;
	if (!_isPresentation) {
		CATransactionNoteChange(); CANotify(self);
		if (pd->flags & CAF_X) [self setNeedsDisplay];
		if (i == CAP_bounds) { [self _boundsChanged]; }
		if (action) [self _runAction:action forKey:@(pd->name)];
	}
}
- (void)_storeAt:(char *)slot type:(CAType)t from:(const void *)p
{
	switch (t) {
	case CAT_COL: case CAT_PATH: CAStoreCF((void **)slot, *(void *const *)p); break;
	case CAT_OBJ: case CAT_STR: case CAT_ARR: CAStoreObject((__unsafe_unretained id *)(void *)slot, *(__unsafe_unretained id const *)p); break;
	case CAT_TF: memcpy(slot, p, 128); break; case CAT_RC: memcpy(slot, p, 32); break; case CAT_PT: case CAT_SZ: memcpy(slot, p, 16); break;
	case CAT_D: case CAT_UL: memcpy(slot, p, 8); break; case CAT_B: memcpy(slot, p, sizeof(BOOL)); break; default: memcpy(slot, p, 4);
	}
}
static void CASetProp(CALayer *l, int i, const void *p) { [l _changeIndex:i toBytes:p isObject:NO]; }
static void CASetObjProp(CALayer *l, int i, id v) { __unsafe_unretained id u = v; [l _changeIndex:i toBytes:&u isObject:YES]; }

- (void)_setBoxed:(id)v forIndex:(int)i
{
	const CAPropDesc *pd = &kCAProps[i];
	union { char bytes[128]; void *ptr; } u; memset(&u, 0, sizeof u);
	switch (pd->type) {
	case CAT_COL:
		if (v && CAIsColor(v)) { u.ptr = (__bridge void *)v; [self _changeIndex:i toBytes:&u isObject:NO]; } else if (!v) [self _changeIndex:i toBytes:&u isObject:NO];
		return;
	case CAT_PATH:
		if (!v || CAIsPath(v)) { u.ptr = (__bridge void *)v; [self _changeIndex:i toBytes:&u isObject:NO]; }
		return;
	case CAT_OBJ: case CAT_STR: case CAT_ARR: { id cp = (pd->type == CAT_STR || pd->type == CAT_ARR) ? [v copy] : v; __unsafe_unretained id o = cp; [self _changeIndex:i toBytes:&o isObject:YES]; return; }
	default:
		if (CAUnbox(pd->type, v, u.bytes)) [self _changeIndex:i toBytes:u.bytes isObject:NO];
	}
}

/* ---- KVC ---------------------------------------------------------------------------------------------------------------------------------------------------------- */
- (id)valueForKey:(NSString *)key
{
	int i = CAPropIndex(key);
	if (i >= 0) return [self _boxedPropertyAtIndex:i];
	return [super valueForKey:key];
}
- (void)setValue:(id)v forKey:(NSString *)key
{
	int i = CAPropIndex(key);
	if (i >= 0) { [self _setBoxed:v forIndex:i]; return; }
	[super setValue:v forKey:key];
}
- (id)valueForKeyPath:(NSString *)kp { return CALayerValueForKeyPath(self, kp); }
- (void)setValue:(id)v forKeyPath:(NSString *)kp { CALayerSetValueForKeyPath(self, kp, v); }

/* the media timing of the layer */
- (CFTimeInterval)beginTime { return _beginTime; }
- (void)setBeginTime:(CFTimeInterval)v { _beginTime = v; _version++; }
- (CFTimeInterval)duration { return _duration; }
- (void)setDuration:(CFTimeInterval)v { _duration = v; _version++; }
- (float)speed { return _speed; }
- (void)setSpeed:(float)v { _speed = v; _version++; }
- (CFTimeInterval)timeOffset { return _timeOffset; }
- (void)setTimeOffset:(CFTimeInterval)v { _timeOffset = v; _version++; }
- (float)repeatCount { return _repeatCount; }
- (void)setRepeatCount:(float)v { _repeatCount = v; _version++; }
- (CFTimeInterval)repeatDuration { return _repeatDuration; }
- (void)setRepeatDuration:(CFTimeInterval)v { _repeatDuration = v; _version++; }
- (BOOL)autoreverses { return _autoreverses; }
- (void)setAutoreverses:(BOOL)v { _autoreverses = v; _version++; }
- (NSString *)fillMode { return _fillMode; }
- (void)setFillMode:(NSString *)v { _fillMode = [v copy]; _version++; }
- (id<CALayerDelegate>)delegate { return _delegate; }
- (void)setDelegate:(id<CALayerDelegate>)v { _delegate = v; }
- (NSDictionary *)actions { return _actions; }
- (void)setActions:(NSDictionary *)v { _actions = [v copy]; }
- (id<CALayoutManager>)layoutManager { return _layoutManager; }
- (void)setLayoutManager:(id<CALayoutManager>)v { _layoutManager = v; }
- (CALayer *)superlayer { return _superlayer; }
- (CALayer *)mask { return _mask; }
- (void)setMask:(CALayer *)m
{
	if (m == _mask) return;
	id action = !_isPresentation && ![CATransaction disableActions] ? [self _actionForPropertyChange:@"mask" flags:CAF_T] : nil;
	if (_mask) _mask->_maskedLayer = nil;
	_mask = m; if (m) { [m removeFromSuperlayer]; m->_maskedLayer = self; }
	_version++; CATransactionNoteChange();
	if (action) [self _runAction:action forKey:@"mask"];
}

/* ---- sublayers ----------------------------------------------------------------------------------------------------------------------------------------------------- */
- (NSArray *)sublayers { return _sublayers.count ? [_sublayers copy] : nil; }
- (void)setSublayers:(NSArray *)s
{
	NSArray *old = [_sublayers copy];
	for (CALayer *l in old) if (![s containsObject:l]) { l->_superlayer = nil; }
	_sublayers = [NSMutableArray array];
	for (CALayer *l in s) { if (l->_superlayer && l->_superlayer != self) [l->_superlayer->_sublayers removeObject:l]; l->_superlayer = self; [_sublayers addObject:l]; }
	[self _sublayersChanged];
}
- (void)_sublayersChanged
{
	_version++; CATransactionNoteChange(); CANotify(self);
	if (_isPresentation || [CATransaction disableActions]) return;
	id action = [self _actionForPropertyChange:@"sublayers" flags:CAF_T];
	if (action) [self _runAction:action forKey:@"sublayers"];
}
- (void)addSublayer:(CALayer *)l { [self insertSublayer:l atIndex:(unsigned)_sublayers.count]; }
- (void)insertSublayer:(CALayer *)l atIndex:(unsigned)idx
{
	if (!l || l == self) return;
	CALayer *oldParent = l->_superlayer;
	if (oldParent) { NSUInteger k = [oldParent->_sublayers indexOfObjectIdenticalTo:l]; [oldParent->_sublayers removeObjectAtIndex:k]; if (oldParent == self && k < idx) idx--; }
	if (!_sublayers) _sublayers = [NSMutableArray array];
	if (idx > _sublayers.count) idx = (unsigned)_sublayers.count;
	[_sublayers insertObject:l atIndex:idx]; l->_superlayer = self;
	if (oldParent && oldParent != self) [oldParent _sublayersChanged];
	[self _sublayersChanged];
	[self setNeedsLayout];
}
- (void)insertSublayer:(CALayer *)l below:(CALayer *)s { NSUInteger k = s ? [_sublayers indexOfObjectIdenticalTo:s] : NSNotFound; [self insertSublayer:l atIndex:k == NSNotFound ? 0 : (unsigned)k]; }
- (void)insertSublayer:(CALayer *)l above:(CALayer *)s { NSUInteger k = s ? [_sublayers indexOfObjectIdenticalTo:s] : NSNotFound; [self insertSublayer:l atIndex:k == NSNotFound ? (unsigned)_sublayers.count : (unsigned)k + 1]; }
- (void)replaceSublayer:(CALayer *)o with:(CALayer *)n
{
	NSUInteger k = [_sublayers indexOfObjectIdenticalTo:o]; if (k == NSNotFound) return;
	[_sublayers removeObjectAtIndex:k]; o->_superlayer = nil;
	if (n) { CALayer *op = n->_superlayer; if (op) [op->_sublayers removeObject:n]; [_sublayers insertObject:n atIndex:MIN(k, _sublayers.count)]; n->_superlayer = self; }
	[self _sublayersChanged];
}
- (void)removeFromSuperlayer
{
	CALayer *p = _superlayer; if (!p) return;
	[p->_sublayers removeObjectIdenticalTo:self]; _superlayer = nil;
	[p _sublayersChanged];
}

/* ---- geometry --------------------------------------------------------------------------------------------------------------------------------------------------------- */
- (CGAffineTransform)affineTransform { return CATransform3DGetAffineTransform(d.transform); }
- (void)setAffineTransform:(CGAffineTransform)m { [self setTransform:CATransform3DMakeAffineTransform(m)]; }

/* the matrix from the layer's own coordinates to the coordinates of its superlayer's content */
- (CATransform3D)_localToSuperMatrix
{
	CGRect b = d.bounds;
	CGFloat ax = b.origin.x + d.anchorPoint.x * b.size.width, ay = b.origin.y + d.anchorPoint.y * b.size.height;
	CATransform3D m = CATransform3DIdentity;
	m = CATransform3DConcat(m, CATransform3DMakeTranslation(-ax, -ay, -d.anchorPointZ));
	m = CATransform3DConcat(m, d.transform);
	CALayer *s = _superlayer;
	/* in a flipped superlayer the positions of the sublayers are measured from the top: the axes of the sublayer stay as they are */
	CGFloat py = (s && s->d.geometryFlipped) ? 2 * s->d.bounds.origin.y + s->d.bounds.size.height - d.position.y : d.position.y;
	m = CATransform3DConcat(m, CATransform3DMakeTranslation(d.position.x, py, d.zPosition));
	if (s && !CATransform3DIsIdentity(s->d.sublayerTransform)) {
		CGRect sb = s->d.bounds; CGFloat sx = sb.origin.x + s->d.anchorPoint.x * sb.size.width, sy = sb.origin.y + s->d.anchorPoint.y * sb.size.height;
		CATransform3D st = CATransform3DConcat(CATransform3DConcat(CATransform3DMakeTranslation(-sx, -sy, -s->d.anchorPointZ), s->d.sublayerTransform), CATransform3DMakeTranslation(sx, sy, s->d.anchorPointZ));
		m = CATransform3DConcat(m, st);
	}
	return m;
}
static CGPoint CAApply(CATransform3D m, CGPoint p)
{
	double x = p.x, y = p.y;
	double w = x * m.m14 + y * m.m24 + m.m44;
	double rx = x * m.m11 + y * m.m21 + m.m41, ry = x * m.m12 + y * m.m22 + m.m42;
	if (w != 1 && w != 0) { rx /= w; ry /= w; }
	return CGPointMake(rx, ry);
}
- (CGRect)frame
{
	CGRect b = d.bounds;
	if (CATransform3DIsIdentity(d.transform)) {
		return CGRectMake(d.position.x - d.anchorPoint.x * b.size.width, d.position.y - d.anchorPoint.y * b.size.height, b.size.width, b.size.height);
	}
	CATransform3D m = [self _localToSuperMatrix];
	CGPoint c[4] = { CAApply(m, CGPointMake(b.origin.x, b.origin.y)), CAApply(m, CGPointMake(b.origin.x + b.size.width, b.origin.y)), CAApply(m, CGPointMake(b.origin.x, b.origin.y + b.size.height)), CAApply(m, CGPointMake(b.origin.x + b.size.width, b.origin.y + b.size.height)) };
	CGFloat x0 = c[0].x, x1 = c[0].x, y0 = c[0].y, y1 = c[0].y;
	for (int i = 1; i < 4; i++) { x0 = MIN(x0, c[i].x); x1 = MAX(x1, c[i].x); y0 = MIN(y0, c[i].y); y1 = MAX(y1, c[i].y); }
	return CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
- (void)setFrame:(CGRect)f
{
	CGRect b = d.bounds;
	if (CATransform3DIsIdentity(d.transform)) {
		CGRect nb = CGRectMake(b.origin.x, b.origin.y, f.size.width, f.size.height);
		[self setBounds:nb];
		[self setPosition:CGPointMake(f.origin.x + d.anchorPoint.x * f.size.width, f.origin.y + d.anchorPoint.y * f.size.height)];
		return;
	}
	CGRect cur = [self frame];
	CGFloat sx = cur.size.width ? f.size.width / cur.size.width : 1, sy = cur.size.height ? f.size.height / cur.size.height : 1;
	[self setBounds:CGRectMake(b.origin.x, b.origin.y, b.size.width * sx, b.size.height * sy)];
	[self setPosition:CGPointMake(d.position.x + (f.origin.x + f.size.width / 2 - (cur.origin.x + cur.size.width / 2)), d.position.y + (f.origin.y + f.size.height / 2 - (cur.origin.y + cur.size.height / 2)))];
}
- (BOOL)contentsAreFlipped { return NO; }

static CATransform3D CALayerToRoot(CALayer *l)
{
	CATransform3D m = CATransform3DIdentity;
	for (CALayer *x = l; x; x = x->_superlayer) m = CATransform3DConcat(m, [x _localToSuperMatrix]);
	return m;
}
- (CGPoint)convertPoint:(CGPoint)p fromLayer:(CALayer *)l
{
	if (!l) return [self _fromRoot:p];
	return [self _fromRoot:CAApply(CALayerToRoot(l), p)];
}
- (CGPoint)_fromRoot:(CGPoint)p
{
	CATransform3D inv = CATransform3DInvert(CALayerToRoot(self));
	return CAApply(inv, p);
}
- (CGPoint)convertPoint:(CGPoint)p toLayer:(CALayer *)l
{
	CGPoint r = CAApply(CALayerToRoot(self), p);
	return l ? [l _fromRoot:r] : r;
}
- (CGRect)convertRect:(CGRect)r fromLayer:(CALayer *)l
{
	CGPoint a = [self convertPoint:r.origin fromLayer:l], b = [self convertPoint:CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r)) fromLayer:l];
	CGPoint c = [self convertPoint:CGPointMake(r.origin.x, CGRectGetMaxY(r)) fromLayer:l], e = [self convertPoint:CGPointMake(CGRectGetMaxX(r), r.origin.y) fromLayer:l];
	CGFloat x0 = MIN(MIN(a.x, b.x), MIN(c.x, e.x)), x1 = MAX(MAX(a.x, b.x), MAX(c.x, e.x)), y0 = MIN(MIN(a.y, b.y), MIN(c.y, e.y)), y1 = MAX(MAX(a.y, b.y), MAX(c.y, e.y));
	return CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
- (CGRect)convertRect:(CGRect)r toLayer:(CALayer *)l
{
	CGPoint a = [self convertPoint:r.origin toLayer:l], b = [self convertPoint:CGPointMake(CGRectGetMaxX(r), CGRectGetMaxY(r)) toLayer:l];
	CGPoint c = [self convertPoint:CGPointMake(r.origin.x, CGRectGetMaxY(r)) toLayer:l], e = [self convertPoint:CGPointMake(CGRectGetMaxX(r), r.origin.y) toLayer:l];
	CGFloat x0 = MIN(MIN(a.x, b.x), MIN(c.x, e.x)), x1 = MAX(MAX(a.x, b.x), MAX(c.x, e.x)), y0 = MIN(MIN(a.y, b.y), MIN(c.y, e.y)), y1 = MAX(MAX(a.y, b.y), MAX(c.y, e.y));
	return CGRectMake(x0, y0, x1 - x0, y1 - y0);
}
- (BOOL)containsPoint:(CGPoint)p { CGRect b = d.bounds; return p.x >= b.origin.x && p.x < b.origin.x + b.size.width && p.y >= b.origin.y && p.y < b.origin.y + b.size.height; }
- (CALayer *)hitTest:(CGPoint)p
{
	/* p is in the coordinates of the superlayer */
	if (d.hidden || d.opacity <= 0) return nil;
	CGPoint lp = _superlayer ? [self convertPoint:p fromLayer:_superlayer] : [self _fromRoot:p];
	if (!_superlayer) lp = [self _fromRoot:p];
	if (![self containsPoint:lp] && !_sublayers.count) return nil;
	if (![self containsPoint:lp] && d.masksToBounds) return nil;
	for (CALayer *s in [_sublayers reverseObjectEnumerator]) { CALayer *h = [s hitTest:lp]; if (h) return h; }
	return [self containsPoint:lp] ? self : nil;
}

/* ---- time ---------------------------------------------------------------------------------------------------------------------------------------------------------- */
- (CFTimeInterval)convertTime:(CFTimeInterval)t fromLayer:(CALayer *)l { return [self _convertTime:t from:l to:self]; }
- (CFTimeInterval)convertTime:(CFTimeInterval)t toLayer:(CALayer *)l { return [self _convertTime:t from:self to:l]; }
/* the layers from `l` up to the root */
static NSArray *CAChain(CALayer *l) { NSMutableArray *a = [NSMutableArray array]; for (; l; l = l->_superlayer) [a addObject:l]; return a; }
- (CFTimeInterval)_convertTime:(CFTimeInterval)t from:(CALayer *)from to:(CALayer *)to
{
	if (from == to) return t;
	NSArray *fa = CAChain(from), *ta = CAChain(to);
	NSUInteger fi = fa.count, ti = ta.count;
	while (fi > 0 && ti > 0 && fa[fi - 1] == ta[ti - 1]) { fi--; ti--; }
	double v = t;
	for (NSUInteger i = 0; i < fi; i++) { CATiming tm; if (CATimingFromObject(fa[i], &tm)) CATimingInverseMapTime(&tm, &v, v); }
	for (NSInteger i = (NSInteger)ti - 1; i >= 0; i--) { CATiming tm; if (CATimingFromObject(ta[i], &tm)) { if (!CATimingMapTime(&tm, &v)) return v; } }
	return v;
}
/* the time of this layer for the time of the current transaction */
- (CFTimeInterval)_localTime { return [self _convertTime:CATransactionTime() from:nil to:self]; }

/* ---- display and layout ------------------------------------------------------------------------------------------------------------------------------------------ */
- (void)setNeedsDisplay { _needsDisplay = YES; CATransactionNoteChange(); CANotify(self); }
- (void)setNeedsDisplayInRect:(CGRect)r { _needsDisplay = YES; CATransactionNoteChange(); CANotify(self); }
- (BOOL)needsDisplay { return _needsDisplay; }
- (void)displayIfNeeded { if (_needsDisplay) [self display]; }
- (void)display
{
	_needsDisplay = NO;
	if ([_delegate respondsToSelector:@selector(displayLayer:)]) { [_delegate displayLayer:self]; return; }
	CGRect b = d.bounds;
	if (!([_delegate respondsToSelector:@selector(drawLayer:inContext:)] || [self _drawsContents])) return;
	size_t w = (size_t)ceil(b.size.width * d.contentsScale), h = (size_t)ceil(b.size.height * d.contentsScale);
	if (!w || !h) return;
	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, w * 4, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little);
	CGColorSpaceRelease(cs);
	if (!ctx) return;
	CGContextTranslateCTM(ctx, 0, h); CGContextScaleCTM(ctx, d.contentsScale, -d.contentsScale);
	if ([_delegate respondsToSelector:@selector(layerWillDraw:)]) [_delegate layerWillDraw:self];
	[self drawInContext:ctx];
	CGImageRef img = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	if (img) { [self setContents:CFBridgingRelease(img)]; }
}
- (BOOL)_drawsContents { return [self class] != [CALayer class] && NO; }
- (void)drawInContext:(CGContextRef)ctx
{
	if ([_delegate respondsToSelector:@selector(drawLayer:inContext:)]) [_delegate drawLayer:self inContext:ctx];
}
- (void)renderInContext:(CGContextRef)ctx { CARenderLayerTree(self, ctx); }
- (void)_boundsChanged
{
	[self setNeedsLayout];
	if (d.needsDisplayOnBoundsChange) [self setNeedsDisplay];
	for (CALayer *s in _sublayers) { [s resizeWithOldSuperlayerSize:CGSizeZero]; }
}
- (void)setNeedsLayout { _needsLayout = YES; }
- (BOOL)needsLayout { return _needsLayout; }
- (void)layoutIfNeeded { if (_needsLayout) { [self layoutSublayers]; } for (CALayer *s in [_sublayers copy]) [s layoutIfNeeded]; }
- (void)layoutSublayers
{
	_needsLayout = NO;
	if ([_layoutManager respondsToSelector:@selector(layoutSublayersOfLayer:)]) { [_layoutManager layoutSublayersOfLayer:self]; return; }
	if ([_delegate respondsToSelector:@selector(layoutSublayersOfLayer:)]) [_delegate layoutSublayersOfLayer:self];
}
- (CGSize)preferredFrameSize
{
	if ([_layoutManager respondsToSelector:@selector(preferredSizeOfLayer:)]) return [_layoutManager preferredSizeOfLayer:self];
	return d.bounds.size;
}
- (void)resizeSublayersWithOldSize:(CGSize)size { for (CALayer *s in _sublayers) [s resizeWithOldSuperlayerSize:size]; }
- (void)resizeWithOldSuperlayerSize:(CGSize)old
{
	unsigned m = d.autoresizingMask; if (!m || !_superlayer) return;
	CGSize ns = _superlayer->d.bounds.size; CGRect f = [self frame];
	CGFloat dw = ns.width - old.width, dh = ns.height - old.height;
	/* the free space is shared between the flexible parts, equally */
	int fx = ((m & kCALayerMinXMargin) ? 1 : 0) + ((m & kCALayerWidthSizable) ? 1 : 0) + ((m & kCALayerMaxXMargin) ? 1 : 0);
	int fy = ((m & kCALayerMinYMargin) ? 1 : 0) + ((m & kCALayerHeightSizable) ? 1 : 0) + ((m & kCALayerMaxYMargin) ? 1 : 0);
	if (fx) { CGFloat e = dw / fx; if (m & kCALayerMinXMargin) f.origin.x += e; if (m & kCALayerWidthSizable) f.size.width += e; }
	if (fy) { CGFloat e = dh / fy; if (m & kCALayerMinYMargin) f.origin.y += e; if (m & kCALayerHeightSizable) f.size.height += e; }
	[self setFrame:f];
}

/* ---- actions ---------------------------------------------------------------------------------------------------------------------------------------------------------- */
+ (id<CAAction>)defaultActionForKey:(NSString *)event { return nil; }
+ (CGFloat)cornerCurveExpansionFactor:(NSString *)curve { return [curve isEqualToString:@"continuous"] ? 1.528665 : 1; }
- (id<CAAction>)actionForKey:(NSString *)event
{
	id a = nil;
	if ([_delegate respondsToSelector:@selector(actionForLayer:forKey:)]) a = [_delegate actionForLayer:self forKey:event];
	if (!a) a = _actions[event];
	if (!a) {
		NSDictionary *s = d.style;
		while (s && !a) { a = ((NSDictionary *)s[@"actions"])[event]; s = s[@"style"]; }
	}
	if (!a) a = [[self class] defaultActionForKey:event];
	if (!a && [self _inContext]) a = [self _implicitAnimationForKeyPath:event];
	return (id)a == (id)[NSNull null] ? nil : a;
}
- (id)_actionForPropertyChange:(NSString *)key flags:(unsigned)flags
{
	/* a change makes an action only when the layer is in a rendered tree (or a delegate / the actions dictionary asks for one) */
	id a = nil;
	if ([_delegate respondsToSelector:@selector(actionForLayer:forKey:)]) a = [_delegate actionForLayer:self forKey:key];
	if (!a) a = _actions[key];
	if (!a) { NSDictionary *s = d.style; while (s && !a) { a = ((NSDictionary *)s[@"actions"])[key]; s = s[@"style"]; } }
	if (!a) a = [[self class] defaultActionForKey:key];
	if (!a && (flags & (CAF_A | CAF_T)) && [self _inContext]) a = [self _implicitAnimationForKeyPath:key];
	if ((id)a == (id)[NSNull null]) return nil;
	return a;
}
- (CAAnimation *)_implicitAnimationForKeyPath:(NSString *)key
{
	int i = CAPropIndex(key);
	BOOL sublayers = [key isEqualToString:@"sublayers"] || [key isEqualToString:@"mask"];
	if (i < 0 && !sublayers) return nil;
	if ([CATransaction animationDuration] == 0) return nil;
	unsigned fl = sublayers ? CAF_T : kCAProps[i].flags;
	if (fl & CAF_T) {
		CATransition *t = [CATransition animation];
		[self _configureImplicit:t];
		return t;
	}
	if (!(fl & CAF_A)) return nil;
	id from = nil;
	if (!(fl & CAF_N)) {
		CALayer *pres = _isPresentation ? self : [self presentationLayer];
		from = pres ? [pres valueForKey:key] : nil;
		if (!from) return nil;
	}
	CABasicAnimation *a = [CABasicAnimation animation];
	a.keyPath = key; a.fromValue = from;
	[self _configureImplicit:a];
	return a;
}
- (void)_configureImplicit:(CAAnimation *)a
{
	a.duration = [CATransaction animationDuration];
	a.timingFunction = [CATransaction animationTimingFunction] ?: [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
	a.fillMode = kCAFillModeBackwards;
	if ([a isKindOfClass:[CATransition class]]) a.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionDefault];
}
- (void)_runAction:(id)action forKey:(NSString *)key
{
	if ([action isKindOfClass:[CATransition class]]) key = kCATransition;
	if ([action respondsToSelector:@selector(runActionForKey:object:arguments:)]) [action runActionForKey:key object:self arguments:nil];
}

/* ---- animations ---------------------------------------------------------------------------------------------------------------------------------------------------- */
- (void)addAnimation:(CAAnimation *)anim forKey:(NSString *)key
{
	if (!anim) return;
	CAAnimation *c = [anim copy];
	[c setDefaultDuration:[CATransaction animationDuration]];
	if (c.beginTime == 0) { [c _setAddedAt:[self _localTime]]; }
	CALayerEntry *e = [CALayerEntry new]; e->key = key ?: [NSString stringWithFormat:@"\001anon%llu", (unsigned long long)++gGeneration]; e->anim = c;
	if (!_anims) _anims = [NSMutableArray array];
	for (CALayerEntry *o in [_anims copy]) if ([o->key isEqualToString:e->key]) { [_anims removeObject:o]; [self _animationRemoved:o finished:NO]; }
	[_anims addObject:e];
	if (!gAnimatedLayers) gAnimatedLayers = [NSHashTable weakObjectsHashTable];
	[gAnimatedLayers addObject:self];
	_version++; gGeneration++;
	CATransactionNoteChange(); CANotify(self);
}
- (void)_animationRemoved:(CALayerEntry *)e finished:(BOOL)f
{
	id dl = e->anim.delegate;
	if (e->started && [dl respondsToSelector:@selector(animationDidStop:finished:)]) [dl animationDidStop:e->anim finished:f];
}
- (void)removeAllAnimations { for (CALayerEntry *e in [_anims copy]) [self _animationRemoved:e finished:NO]; [_anims removeAllObjects]; _version++; gGeneration++; }
- (void)removeAnimationForKey:(NSString *)key
{
	for (CALayerEntry *e in [_anims copy]) if ([e->key isEqualToString:key]) { [_anims removeObject:e]; [self _animationRemoved:e finished:NO]; }
	_version++; gGeneration++;
}
- (NSArray *)animationKeys { NSMutableArray *k = [NSMutableArray array]; for (CALayerEntry *e in _anims) if (![e->key hasPrefix:@"\x01"]) [k addObject:e->key]; return k.count ? k : nil; }
- (CAAnimation *)animationForKey:(NSString *)key { for (CALayerEntry *e in _anims) if ([e->key isEqualToString:key]) return [e->anim copy]; return nil; }

/* animations that ended are removed (or kept by their fill mode), and the delegates told, when the transaction is committed */
- (void)_commitAnimations
{
	if (!_anims.count) return;
	double now = [self _localTime];
	for (CALayerEntry *e in [_anims copy]) {
		CATiming tm; CAAnimation *a = e->anim;
		BOOL has = CAAnimationTiming(a, &tm);
		if (!e->started) {
			double t = now; BOOL active = !has ? YES : (CATimingMapParentToActive(&tm, &t, NULL) || [a _addedAt] <= now);
			if (active) { e->started = YES; if ([a.delegate respondsToSelector:@selector(animationDidStart:)]) [a.delegate animationDidStart:a]; }
		}
		if (has && e->started) {
			double end = CATimingEndTime(&tm);
			if (now > end && !isinf(end)) {
				e->finished = YES;
				if (a.isRemovedOnCompletion) { [_anims removeObject:e]; [self _animationRemoved:e finished:YES]; _version++; }
				else if (!e->anim.removedOnCompletion) { /* stays; the delegate is told once */ if (e->started) { id dl = a.delegate; e->started = NO; e->finished = YES; if ([dl respondsToSelector:@selector(animationDidStop:finished:)]) [dl animationDidStop:a finished:YES]; } }
			}
		}
	}
}
- (BOOL)_hasAnimations { return _anims.count > 0; }
- (BOOL)_treeHasActiveAnimations:(CFTimeInterval)now
{
	for (CALayerEntry *e in _anims) {
		CAAnimation *a = e->anim; CATiming tm;
		if (!CAAnimationTiming(a, &tm)) return YES;
		double end = CATimingEndTime(&tm); double lt = [self _convertTime:now from:nil to:self];
		if (isinf(end) || lt <= end) return YES;
		if (!a.isRemovedOnCompletion && (tm.fillForwards)) continue;
	}
	for (CALayer *s in _sublayers) if ([s _treeHasActiveAnimations:now]) return YES;
	return [_mask _treeHasActiveAnimations:now];
}
- (void)_refreshPresentation { _presentation = nil; (void)[self presentationLayer]; }

/* a presentation tree for the time t (media time): every node is a presentation layer with the animations applied for t */
- (CALayer *)_presentationTreeAtTime:(CFTimeInterval)t
{
	CALayer *p = [[[self class] alloc] initWithLayer:self];
	p->_isPresentation = YES; p->_model = self;
	double lt = [self _convertTime:t from:nil to:self];
	for (CALayerEntry *e in _anims) [e->anim applyForTime:lt presentationObject:p modelObject:self];
	if (_sublayers.count) {
		p->_sublayers = [NSMutableArray arrayWithCapacity:_sublayers.count];
		for (CALayer *s in _sublayers) { CALayer *c = [s _presentationTreeAtTime:t]; c->_superlayer = p; [p->_sublayers addObject:c]; }
	}
	if (_mask) { p->_mask = [_mask _presentationTreeAtTime:t]; p->_mask->_superlayer = nil; }
	return p;
}
- (NSArray *)_sublayerArray { return _sublayers; }
- (instancetype)modelLayer { return _isPresentation ? _model : self; }
- (instancetype)presentationLayer
{
	if (_isPresentation) return self;
	if (![self _inContext]) return nil;
	CFTimeInterval txn = CATransactionTime();
	if (_presentation && _presentationTime == txn) return _presentation;      /* a snapshot: it is refreshed when the transaction ends */
	CALayer *p = [[[self class] alloc] initWithLayer:self];
	p->_isPresentation = YES; p->_model = self; p->_superlayer = _superlayer;
	p->_sublayers = nil;
	if (_anims.count) {
		double t = [self _localTime];
		for (CALayerEntry *e in _anims) {
			CAAnimation *a = e->anim;
			if (a.beginTime == 0) {}
			[a applyForTime:t presentationObject:p modelObject:self];
		}
	}
	p->_version = _version;
	_presentation = p; _presentationTime = txn; _presentationGen = gGeneration;
	if (!gSnapshotLayers) gSnapshotLayers = [NSHashTable weakObjectsHashTable];
	[gSnapshotLayers addObject:self];
	return p;
}

- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p>", [self class], self]; }
@end

void CALayerCommitAnimations(void)
{
	for (CALayer *r in [gContextRoots allObjects]) [r _markCommitted];
	for (CALayer *l in [gAnimatedLayers allObjects]) [l _commitAnimations];
}

/* after a commit the presentation layers are made again for the new time (the snapshot of a layer is the state at the last commit) */
void CALayerRefreshPresentations(void)
{
	for (CALayer *l in [gSnapshotLayers allObjects]) [l _refreshPresentation];
}

@implementation NSNull (CAActionAdditions)
- (void)runActionForKey:(NSString *)event object:(id)anObject arguments:(NSDictionary *)dict {}
@end

/* ---- subclasses ------------------------------------------------------------------------------------------------------------------------------------------------------- */
@implementation CAShapeLayer
CA_ACCESSORS_CAShapeLayer
@end
@implementation CATextLayer
CA_ACCESSORS_CATextLayer
- (instancetype)init { if ((self = [super init])) { [self _initFont]; } return self; }
- (void)_initFont { }
@end
@implementation CAGradientLayer
CA_ACCESSORS_CAGradientLayer
@end
@implementation CATransformLayer
@end
@implementation CAReplicatorLayer
CA_ACCESSORS_CAReplicatorLayer
@end
@implementation CAScrollLayer
CA_ACCESSORS_CAScrollLayer
- (void)scrollToPoint:(CGPoint)p
{
	NSString *m = [self scrollMode]; CGRect b = self.bounds;
	if ([m isEqualToString:@"vertically"]) p.x = b.origin.x; else if ([m isEqualToString:@"horizontally"]) p.y = b.origin.y; else if ([m isEqualToString:@"none"]) return;
	b.origin = p; self.bounds = b;
}
- (void)scrollToRect:(CGRect)r { [self scrollToPoint:r.origin]; }
@end
@implementation CALayer (CALayerScrolling)
- (CAScrollLayer *)_scrollAncestor { for (CALayer *l = self.superlayer; l; l = l.superlayer) if ([l isKindOfClass:[CAScrollLayer class]]) return (CAScrollLayer *)l; return nil; }
- (void)scrollPoint:(CGPoint)p { CAScrollLayer *s = [self _scrollAncestor]; if (s) [s scrollToPoint:[s convertPoint:p fromLayer:self]]; }
- (void)scrollRectToVisible:(CGRect)r { CAScrollLayer *s = [self _scrollAncestor]; if (s) [s scrollToRect:[s convertRect:r fromLayer:self]]; }
- (CGRect)visibleRect { CAScrollLayer *s = [self _scrollAncestor]; return s ? [self convertRect:s.bounds fromLayer:s] : self.bounds; }
@end
@implementation CATiledLayer
CA_ACCESSORS_CATiledLayer
+ (CFTimeInterval)fadeDuration { return 0.25; }
@end
@implementation CAEmitterLayer
CA_ACCESSORS_CAEmitterLayer
@end

@implementation CAEmitterCell
{
	CFTimeInterval _beginTime, _duration, _timeOffset, _repeatDuration; float _speed, _repeatCount; BOOL _autoreverses; NSString *_fillMode;
}
@synthesize name, enabled, birthRate, lifetime, lifetimeRange, emissionLatitude, emissionLongitude, emissionRange, velocity, velocityRange, xAcceleration, yAcceleration, zAcceleration;
@synthesize scale, scaleRange, scaleSpeed, spin, spinRange, redRange, greenRange, blueRange, alphaRange, redSpeed, greenSpeed, blueSpeed, alphaSpeed, contents, contentsRect, contentsScale;
@synthesize minificationFilter, magnificationFilter, minificationFilterBias, emitterCells, style;
@dynamic color;
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)emitterCell { return [[self alloc] init]; }
+ (id)defaultValueForKey:(NSString *)key { return nil; }
- (BOOL)shouldArchiveValueForKey:(NSString *)key { return YES; }
- (instancetype)init
{
	if ((self = [super init])) {
		enabled = YES; scale = 1; contentsRect = CGRectMake(0, 0, 1, 1); contentsScale = 1; minificationFilter = @"linear"; magnificationFilter = @"linear";
		_speed = 1; _duration = INFINITY; _fillMode = @"removed";
		CGFloat v[4] = { 1, 1, 1, 1 }; CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB(); _color = CGColorCreate(cs, v); CGColorSpaceRelease(cs);
	}
	return self;
}
- (void)dealloc { if (_color) CGColorRelease(_color); }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (id)valueForKey:(NSString *)key { if ([key isEqualToString:@"color"]) return _color ? (__bridge id)_color : nil; if ([key isEqualToString:@"enabled"]) @throw [NSException exceptionWithName:NSUndefinedKeyException reason:@"enabled" userInfo:nil]; return [super valueForKey:key]; }
- (CGColorRef)color { return _color; }
- (void)setColor:(CGColorRef)c { if (c) CGColorRetain(c); if (_color) CGColorRelease(_color); _color = c; }
- (CFTimeInterval)beginTime { return _beginTime; } - (void)setBeginTime:(CFTimeInterval)v { _beginTime = v; }
- (CFTimeInterval)duration { return _duration; } - (void)setDuration:(CFTimeInterval)v { _duration = v; }
- (float)speed { return _speed; } - (void)setSpeed:(float)v { _speed = v; }
- (CFTimeInterval)timeOffset { return _timeOffset; } - (void)setTimeOffset:(CFTimeInterval)v { _timeOffset = v; }
- (float)repeatCount { return _repeatCount; } - (void)setRepeatCount:(float)v { _repeatCount = v; }
- (CFTimeInterval)repeatDuration { return _repeatDuration; } - (void)setRepeatDuration:(CFTimeInterval)v { _repeatDuration = v; }
- (BOOL)autoreverses { return _autoreverses; } - (void)setAutoreverses:(BOOL)v { _autoreverses = v; }
- (NSString *)fillMode { return _fillMode; } - (void)setFillMode:(NSString *)v { _fillMode = [v copy]; }
@end
