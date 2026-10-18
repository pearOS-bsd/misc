/* AppKit animation on top of Core Animation (QuartzCore of this stack): NSAnimationContext with timing function and completion handlers, and the animator proxies of NSView, NSWindow and
 * constraints. The values come from Core Animation's own interpolation (CABasicAnimationValueAtTime), so a frame animation follows the same curve as on a Mac; a timer drives it. */
#import <wsbsd/AppKitCompat.h>
#import <QuartzCore/QuartzCore.h>
#import <QuartzCore/CAWsbsd.h>
#import <objc/runtime.h>

/* ---- the contexts ------------------------------------------------------------------------------------------------------------------------------------------------------ */
@interface WsAnimGroup : NSObject { @public NSInteger pending; BOOL ended; void (^completion)(void); }
- (void)maybeFinish;
@end
@implementation WsAnimGroup
- (void)maybeFinish { if (ended && pending <= 0 && completion) { void (^c)(void) = completion; completion = nil; c(); } }
@end

static const char kTimingKey, kImplicitKey, kGroupKey;
static NSMutableArray *ContextStack(void) { static NSMutableArray *s; if (!s) { s = [NSMutableArray new]; } return s; }
static NSAnimationContext *NewContext(NSAnimationContext *parent)
{
	NSAnimationContext *c = [[NSAnimationContext alloc] init];
	[c setDuration: parent ? [parent duration] : 0.25];
	if (parent) { objc_setAssociatedObject(c, &kTimingKey, objc_getAssociatedObject(parent, &kTimingKey), OBJC_ASSOCIATION_RETAIN_NONATOMIC); objc_setAssociatedObject(c, &kImplicitKey, objc_getAssociatedObject(parent, &kImplicitKey), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
	objc_setAssociatedObject(c, &kGroupKey, [WsAnimGroup new], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	return c;
}

/* GNUstep's NSAnimationContext already has these methods: they are replaced (a category does not reliably win over the class when AppKit is loaded after this library) */
static NSAnimationContext *WsCurrentContext(id self, SEL _cmd)
{
	NSMutableArray *s = ContextStack();
	if (!s.count) [s addObject: NewContext(nil)];
	return s.lastObject;
}
static void WsBeginGrouping(id self, SEL _cmd) { NSMutableArray *s = ContextStack(); if (!s.count) [s addObject: NewContext(nil)]; [s addObject: NewContext(s.lastObject)]; }
static void WsEndGrouping(id self, SEL _cmd)
{
	NSMutableArray *s = ContextStack(); if (s.count <= 1) return;
	NSAnimationContext *c = s.lastObject; [s removeLastObject];
	WsAnimGroup *g = objc_getAssociatedObject(c, &kGroupKey); g->completion = [c completionHandler]; g->ended = YES; [g maybeFinish];
}
static void WsRunGroupCompletion(id self, SEL _cmd, void (^changes)(NSAnimationContext *), void (^completionHandler)(void))
{
	WsBeginGrouping(self, _cmd);
	NSAnimationContext *c = WsCurrentContext(self, _cmd);
	if (completionHandler) [c setCompletionHandler: completionHandler];
	if (changes) changes(c);
	WsEndGrouping(self, _cmd);
}
static void WsRunGroup(id self, SEL _cmd, void (^changes)(NSAnimationContext *)) { WsRunGroupCompletion(self, _cmd, changes, nil); }

@implementation NSAnimationContext (WsbsdContext)
+ (void)load
{
	/* GNUstep has these methods already: replaced with the encoding of the original (its runtime has typed selectors) */
	Class meta = object_getClass([NSAnimationContext class]);
	struct { SEL sel; IMP imp; const char *fallback; } t[] = {
		{ @selector(currentContext), (IMP)WsCurrentContext, "@@:" }, { @selector(beginGrouping), (IMP)WsBeginGrouping, "v@:" }, { @selector(endGrouping), (IMP)WsEndGrouping, "v@:" },
		{ @selector(runAnimationGroup:completionHandler:), (IMP)WsRunGroupCompletion, "v@:@@" }, { @selector(runAnimationGroup:), (IMP)WsRunGroup, "v@:@" } };
	for (size_t i = 0; i < sizeof t / sizeof t[0]; i++) {
		Method m = class_getClassMethod([NSAnimationContext class], t[i].sel);
		class_replaceMethod(meta, t[i].sel, t[i].imp, m ? method_getTypeEncoding(m) : t[i].fallback);
	}
}
- (CAMediaTimingFunction *)timingFunction { return objc_getAssociatedObject(self, &kTimingKey); }
- (void)setTimingFunction:(CAMediaTimingFunction *)f { objc_setAssociatedObject(self, &kTimingKey, f, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (BOOL)allowsImplicitAnimation { return [objc_getAssociatedObject(self, &kImplicitKey) boolValue]; }
- (void)setAllowsImplicitAnimation:(BOOL)f { objc_setAssociatedObject(self, &kImplicitKey, [NSNumber numberWithBool: f], OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end

/* ---- the engine ------------------------------------------------------------------------------------------------------------------------------------------------------- */
@interface WsAnimation : NSObject
{ @public
	__weak id target; NSString *key; CABasicAnimation *anim; CFTimeInterval t0; void (^apply)(id value); WsAnimGroup *group; BOOL cancelled;
}
@end
@implementation WsAnimation @end

@interface WsAnimationEngine : NSObject
+ (void)add:(WsAnimation *)a;
@end
@implementation WsAnimationEngine
static NSMutableArray *gActive; static NSTimer *gTimer;
+ (void)add:(WsAnimation *)a
{
	if (!gActive) gActive = [NSMutableArray new];
	for (WsAnimation *o in [gActive copy]) if (o->target == a->target && [o->key isEqualToString: a->key]) { o->cancelled = YES; [gActive removeObject: o]; if (o->group) { o->group->pending--; [o->group maybeFinish]; } }
	[gActive addObject: a];
	if (!gTimer) {
		gTimer = [NSTimer timerWithTimeInterval: 1.0 / 60 target: self selector: @selector(tick:) userInfo: nil repeats: YES];
		[[NSRunLoop currentRunLoop] addTimer: gTimer forMode: NSRunLoopCommonModes];
		[[NSRunLoop currentRunLoop] addTimer: gTimer forMode: NSDefaultRunLoopMode];
	}
}
+ (void)tick:(NSTimer *)t
{
	CFTimeInterval now = CACurrentMediaTime();
	for (WsAnimation *a in [gActive copy]) {
		if (a->cancelled) continue;
		if (!a->target) { [gActive removeObject: a]; if (a->group) { a->group->pending--; [a->group maybeFinish]; } continue; }
		CFTimeInterval el = now - a->t0; BOOL done = el >= [a->anim duration];
		id v = done ? [a->anim toValue] : CABasicAnimationValueAtTime(a->anim, el);
		if (!v) v = [a->anim toValue];
		a->apply(v);
		if (done) { [gActive removeObject: a]; if (a->group) { a->group->pending--; [a->group maybeFinish]; } }
	}
	if (!gActive.count) { [gTimer invalidate]; gTimer = nil; }
}
@end

/* ---- the animator proxies ------------------------------------------------------------------------------------------------------------------------------------------ */
typedef enum { kAPFrame, kAPFrameOrigin, kAPFrameSize, kAPBounds, kAPBoundsOrigin, kAPBoundsSize, kAPNumber } APKind;
typedef struct { const char *setter; const char *getter; APKind kind; } APEntry;
static const APEntry kViewProps[] = {
	{ "setFrame:", "frame", kAPFrame }, { "setFrameOrigin:", "frame", kAPFrameOrigin }, { "setFrameSize:", "frame", kAPFrameSize },
	{ "setBounds:", "bounds", kAPBounds }, { "setBoundsOrigin:", "bounds", kAPBoundsOrigin }, { "setBoundsSize:", "bounds", kAPBoundsSize },
	{ "setAlphaValue:", "alphaValue", kAPNumber }, { "setFrameRotation:", "frameRotation", kAPNumber }, { "setBoundsRotation:", "boundsRotation", kAPNumber },
};
static const APEntry kWindowProps[] = {
	{ "setFrame:display:", "frame", kAPFrame }, { "setFrameOrigin:", "frame", kAPFrameOrigin }, { "setAlphaValue:", "alphaValue", kAPNumber },
	{ "setFrame:display:animate:", "frame", kAPFrame }, { "setContentSize:", "contentSize", kAPNumber },
};
static const APEntry kConstraintProps[] = { { "setConstant:", "constant", kAPNumber } };

@interface WsAnimatorProxy : NSProxy { id _target; const APEntry *_table; size_t _n; }
+ (instancetype)proxyFor:(id)target;
@end
@implementation WsAnimatorProxy
+ (instancetype)proxyFor:(id)target
{
	WsAnimatorProxy *p = [WsAnimatorProxy alloc]; p->_target = target;
	if ([target isKindOfClass: [NSView class]]) { p->_table = kViewProps; p->_n = sizeof kViewProps / sizeof kViewProps[0]; }
	else if ([target isKindOfClass: [NSWindow class]]) { p->_table = kWindowProps; p->_n = sizeof kWindowProps / sizeof kWindowProps[0]; }
	else if ([target isKindOfClass: NSClassFromString(@"NSLayoutConstraint")]) { p->_table = kConstraintProps; p->_n = 1; }
	return p;
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel { return [_target methodSignatureForSelector: sel]; }
- (BOOL)respondsToSelector:(SEL)sel { return [_target respondsToSelector: sel]; }
- (id)forwardingTargetForSelector:(SEL)sel
{
	for (size_t i = 0; i < _n; i++) if (!strcmp(_table[i].setter, sel_getName(sel))) return nil;
	return _target;
}
static NSRect RectOf(id v) { NSRect r = NSZeroRect; [v getValue: &r]; return r; }
- (void)forwardInvocation:(NSInvocation *)inv
{
	const APEntry *e = NULL;
	for (size_t i = 0; i < _n; i++) if (!strcmp(_table[i].setter, sel_getName([inv selector]))) { e = &_table[i]; break; }
	NSAnimationContext *ctx = [NSAnimationContext currentContext];
	if (!e || [ctx duration] <= 0) { [inv invokeWithTarget: _target]; return; }
	NSMethodSignature *sig = [inv methodSignature];
	const char *type = [sig getArgumentTypeAtIndex: 2];
	char buf[64] = { 0 }; [inv getArgument: buf atIndex: 2];
	id target = _target;
	id (^current)(void) = ^id{ return [target valueForKey: [NSString stringWithUTF8String: e->getter]]; };
	id from, to; NSRect curRect = NSZeroRect;
	id curV = current();
	switch (e->kind) {
	case kAPFrame: case kAPBounds: from = curV; to = [NSValue valueWithBytes: buf objCType: type]; break;
	case kAPFrameOrigin: case kAPBoundsOrigin: { curRect = RectOf(curV); NSPoint p; memcpy(&p, buf, sizeof p); from = [NSValue valueWithPoint: curRect.origin]; to = [NSValue valueWithPoint: p]; break; }
	case kAPFrameSize: case kAPBoundsSize: { curRect = RectOf(curV); NSSize s; memcpy(&s, buf, sizeof s); from = [NSValue valueWithSize: curRect.size]; to = [NSValue valueWithSize: s]; break; }
	default: { double d = type[0] == 'f' ? *(float *)buf : *(double *)buf; from = curV ?: @0; to = [NSNumber numberWithDouble: d]; break; }
	}
	CABasicAnimation *a = [CABasicAnimation animationWithKeyPath: @"value"];
	a.fromValue = from; a.toValue = to; a.duration = [ctx duration]; a.timingFunction = [ctx timingFunction] ?: [CAMediaTimingFunction functionWithName: kCAMediaTimingFunctionDefault];
	a.fillMode = kCAFillModeForwards; a.removedOnCompletion = NO;
	[inv retainArguments];
	WsAnimation *w = [WsAnimation new]; w->target = target; w->key = [NSString stringWithUTF8String: e->setter]; w->anim = a; w->t0 = CACurrentMediaTime();
	WsAnimGroup *g = objc_getAssociatedObject(ctx, &kGroupKey); w->group = g; if (g) g->pending++;
	NSInvocation *call = inv; APKind kind = e->kind;
	w->apply = ^(id v) {
		char out[64] = { 0 };
		switch (kind) {
		case kAPFrameOrigin: case kAPBoundsOrigin: { NSPoint p = [v pointValue]; memcpy(out, &p, sizeof p); break; }
		case kAPFrameSize: case kAPBoundsSize: { NSSize s = [v sizeValue]; memcpy(out, &s, sizeof s); break; }
		case kAPFrame: case kAPBounds: [v getValue: out]; break;
		default: { double d = [v doubleValue]; if (type[0] == 'f') { float f = (float)d; memcpy(out, &f, sizeof f); } else memcpy(out, &d, sizeof d); }
		}
		[call setArgument: out atIndex: 2]; [call invokeWithTarget: target];
	};
	[WsAnimationEngine add: w];
}
@end

@implementation NSView (WsbsdAnimator)
- (id)animator { return [WsAnimatorProxy proxyFor: self]; }
+ (id)defaultAnimationForKey:(NSString *)key { return nil; }
@end
@implementation NSWindow (WsbsdAnimator)
- (id)animator { return [WsAnimatorProxy proxyFor: self]; }
@end
