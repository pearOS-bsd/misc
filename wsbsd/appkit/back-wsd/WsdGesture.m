/* NSGestureRecognizer and its mouse subclasses (NSClickGestureRecognizer, NSPanGestureRecognizer, NSPressGestureRecognizer) as macOS 10.12 runs them, and the view's list of recognizers.
 * The window feeds every mouse event to the recognizers of the view under the pointer and of its ancestors before the view's own handling. Recognizers that delay the primary button
 * (the default, as on macOS) hold the view's mouseDown / mouseDragged / mouseUp events back until every recognizer has either recognized (the view never sees the events) or failed (the events
 * are replayed to the view). Recognizers: state machine Possible -> Began -> Changed -> Ended (Recognized) / Cancelled / Failed, the action is sent on Began, Changed, Ended; discrete ones reset
 * by themselves. Magnification / rotation need touches and are not here. Compiled without ARC. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <math.h>

enum { GRPossible, GRBegan, GRChanged, GREnded, GRCancelled, GRFailed };

@interface WsdGS : NSObject { @public id target; SEL action; id delegate; NSView *view; NSInteger state; BOOL enabled, delaysPrimary, delaysSecondary, delaysOther, delaysKeys;
	NSString *name; NSUInteger flags;
	NSInteger buttonMask, clicks; NSPoint start, last, translation; NSTimeInterval lastT; NSPoint velocity; NSTimer *timer; double minDuration, allowable; NSInteger clicksSeen; } @end
@implementation WsdGS
- (id)init { if ((self = [super init])) { enabled = YES; delaysPrimary = YES; buttonMask = 1; clicks = 1; minDuration = 0.5; allowable = 10; } return self; }
- (void)dealloc { [name release]; [timer invalidate]; [super dealloc]; }
@end
static char kGS, kList, kActive, kQueue;
static WsdGS *GS(id g) { WsdGS *s = objc_getAssociatedObject(g, &kGS); if (!s) { s = [[[WsdGS alloc] init] autorelease]; objc_setAssociatedObject(g, &kGS, s, OBJC_ASSOCIATION_RETAIN_NONATOMIC); } return s; }

@implementation NSGestureRecognizer (WsdGesture)
- (id)initWithTarget:(id)t action:(SEL)a { if ((self = [self init])) { GS(self)->target = t; GS(self)->action = a; } return self; }
- (id)target { return GS(self)->target; } - (void)setTarget:(id)t { GS(self)->target = t; }
- (SEL)action { return GS(self)->action; } - (void)setAction:(SEL)a { GS(self)->action = a; }
- (id)delegate { return GS(self)->delegate; } - (void)setDelegate:(id)d { GS(self)->delegate = d; }
- (NSView *)view { return GS(self)->view; }
- (BOOL)isEnabled { return GS(self)->enabled; } - (void)setEnabled:(BOOL)b { WsdGS *g = GS(self); g->enabled = b; if (!b && g->state != GRPossible) { g->state = GRCancelled; [self reset]; g->state = GRPossible; } }
- (NSString *)name { return GS(self)->name; } - (void)setName:(NSString *)n { [GS(self)->name release]; GS(self)->name = [n copy]; }
- (NSUInteger)modifierFlags { return GS(self)->flags; }
- (BOOL)delaysPrimaryMouseButtonEvents { return GS(self)->delaysPrimary; } - (void)setDelaysPrimaryMouseButtonEvents:(BOOL)b { GS(self)->delaysPrimary = b; }
- (BOOL)delaysSecondaryMouseButtonEvents { return GS(self)->delaysSecondary; } - (void)setDelaysSecondaryMouseButtonEvents:(BOOL)b { GS(self)->delaysSecondary = b; }
- (BOOL)delaysOtherMouseButtonEvents { return GS(self)->delaysOther; } - (void)setDelaysOtherMouseButtonEvents:(BOOL)b { GS(self)->delaysOther = b; }
- (BOOL)delaysKeyEvents { return GS(self)->delaysKeys; } - (void)setDelaysKeyEvents:(BOOL)b { GS(self)->delaysKeys = b; }
- (NSInteger)state { return GS(self)->state; }
- (void)setState:(NSInteger)s
{
	WsdGS *g = GS(self); g->state = s;
	if ((s == GRBegan || s == GRChanged || s == GREnded) && g->action) [NSApp sendAction: g->action to: g->target from: self];
}
- (NSPoint)locationInView:(NSView *)v
{
	WsdGS *g = GS(self); NSView *rel = v ?: g->view; NSPoint p = g->last;
	return rel ? [rel convertPoint: p fromView: nil] : p;
}
- (void)reset { GS(self)->state = GRPossible; }
- (void)mouseDown:(NSEvent *)e {} - (void)mouseDragged:(NSEvent *)e {} - (void)mouseUp:(NSEvent *)e {}
- (void)rightMouseDown:(NSEvent *)e {} - (void)rightMouseDragged:(NSEvent *)e {} - (void)rightMouseUp:(NSEvent *)e {}
- (void)otherMouseDown:(NSEvent *)e {} - (void)otherMouseDragged:(NSEvent *)e {} - (void)otherMouseUp:(NSEvent *)e {}
- (void)mouseCancelled:(NSEvent *)e {} - (void)keyDown:(NSEvent *)e {} - (void)keyUp:(NSEvent *)e {} - (void)flagsChanged:(NSEvent *)e {}
- (BOOL)canPreventGestureRecognizer:(NSGestureRecognizer *)o { return YES; }
- (BOOL)canBePreventedByGestureRecognizer:(NSGestureRecognizer *)o { return YES; }
- (BOOL)shouldRequireFailureOfGestureRecognizer:(NSGestureRecognizer *)o { return NO; }
- (BOOL)shouldBeRequiredToFailByGestureRecognizer:(NSGestureRecognizer *)o { return NO; }
@end

/* the buttons: 1 = primary (left), 2 = secondary (right), 4 = other */
static NSInteger ButtonBit(NSEvent *e)
{
	switch ([e type]) { case NSLeftMouseDown: case NSLeftMouseUp: case NSLeftMouseDragged: return 1; case NSRightMouseDown: case NSRightMouseUp: case NSRightMouseDragged: return 2; default: return 4; }
}
static BOOL IsDown(NSEvent *e) { return [e type] == NSLeftMouseDown || [e type] == NSRightMouseDown || [e type] == NSOtherMouseDown; }
static BOOL IsUp(NSEvent *e) { return [e type] == NSLeftMouseUp || [e type] == NSRightMouseUp || [e type] == NSOtherMouseUp; }
static BOOL IsDrag(NSEvent *e) { return [e type] == NSLeftMouseDragged || [e type] == NSRightMouseDragged || [e type] == NSOtherMouseDragged; }
static double Dist(NSPoint a, NSPoint b) { return hypot(a.x - b.x, a.y - b.y); }
static void Fail(NSGestureRecognizer *g) { GS(g)->state = GRFailed; }
static void Note(NSGestureRecognizer *g, NSEvent *e) { WsdGS *s = GS(g); s->last = [e locationInWindow]; s->flags = [e modifierFlags]; }

@implementation NSClickGestureRecognizer (WsdGesture)
- (NSInteger)buttonMask { return GS(self)->buttonMask; } - (void)setButtonMask:(NSInteger)m { GS(self)->buttonMask = m; }
- (NSInteger)numberOfClicksRequired { return GS(self)->clicks; } - (void)setNumberOfClicksRequired:(NSInteger)n { GS(self)->clicks = n; }
- (NSInteger)numberOfTouchesRequired { return 1; } - (void)setNumberOfTouchesRequired:(NSInteger)n {}
- (void)wsdDown:(NSEvent *)e
{
	WsdGS *g = GS(self); Note(self, e);
	if (g->clicksSeen == 0) g->start = [e locationInWindow];
	else if (Dist(g->start, [e locationInWindow]) > 4) { g->clicksSeen = 0; g->start = [e locationInWindow]; }
}
- (void)wsdUp:(NSEvent *)e
{
	WsdGS *g = GS(self); Note(self, e);
	if (Dist(g->start, [e locationInWindow]) > 4) { g->clicksSeen = 0; Fail(self); return; }
	g->clicksSeen++;
	if (g->clicksSeen >= g->clicks) { g->clicksSeen = 0; [self setState: GREnded]; }
}
- (void)mouseDown:(NSEvent *)e { if (GS(self)->buttonMask & 1) [self wsdDown: e]; }
- (void)mouseUp:(NSEvent *)e { if (GS(self)->buttonMask & 1) [self wsdUp: e]; }
- (void)rightMouseDown:(NSEvent *)e { if (GS(self)->buttonMask & 2) [self wsdDown: e]; }
- (void)rightMouseUp:(NSEvent *)e { if (GS(self)->buttonMask & 2) [self wsdUp: e]; }
- (void)mouseDragged:(NSEvent *)e { WsdGS *g = GS(self); Note(self, e); if ((g->buttonMask & 1) && Dist(g->start, [e locationInWindow]) > 4) { g->clicksSeen = 0; Fail(self); } }
- (void)reset { GS(self)->state = GRPossible; }
@end

@implementation NSPanGestureRecognizer (WsdGesture)
- (NSInteger)buttonMask { return GS(self)->buttonMask; } - (void)setButtonMask:(NSInteger)m { GS(self)->buttonMask = m; }
- (NSInteger)numberOfTouchesRequired { return 1; } - (void)setNumberOfTouchesRequired:(NSInteger)n {}
- (NSPoint)translationInView:(NSView *)v { WsdGS *g = GS(self); NSView *r = v ?: g->view; NSPoint a = [r convertPoint: g->last fromView: nil], b = [r convertPoint: g->start fromView: nil]; return NSMakePoint(a.x - b.x + g->translation.x, a.y - b.y + g->translation.y); }
- (void)setTranslation:(NSPoint)t inView:(NSView *)v { WsdGS *g = GS(self); NSView *r = v ?: g->view; NSPoint a = [r convertPoint: g->last fromView: nil], b = [r convertPoint: g->start fromView: nil]; g->translation = NSMakePoint(t.x - (a.x - b.x), t.y - (a.y - b.y)); }
- (NSPoint)velocityInView:(NSView *)v { return GS(self)->velocity; }
- (void)wsdDown:(NSEvent *)e { WsdGS *g = GS(self); g->start = g->last = [e locationInWindow]; g->translation = NSZeroPoint; g->velocity = NSZeroPoint; g->lastT = [e timestamp]; }
- (void)wsdDrag:(NSEvent *)e
{
	WsdGS *g = GS(self); NSPoint p = [e locationInWindow]; double dt = [e timestamp] - g->lastT;
	if (dt > 0) g->velocity = NSMakePoint((p.x - g->last.x) / dt, (p.y - g->last.y) / dt);
	g->last = p; g->lastT = [e timestamp]; g->flags = [e modifierFlags];
	if (g->state == GRPossible) { if (Dist(g->start, p) >= 4) [self setState: GRBegan]; }
	else if (g->state == GRBegan || g->state == GRChanged) [self setState: GRChanged];
}
- (void)wsdUp:(NSEvent *)e
{
	WsdGS *g = GS(self); g->last = [e locationInWindow];
	if (g->state == GRBegan || g->state == GRChanged) [self setState: GREnded]; else Fail(self);
}
- (void)mouseDown:(NSEvent *)e { if (GS(self)->buttonMask & 1) [self wsdDown: e]; } - (void)mouseDragged:(NSEvent *)e { if (GS(self)->buttonMask & 1) [self wsdDrag: e]; } - (void)mouseUp:(NSEvent *)e { if (GS(self)->buttonMask & 1) [self wsdUp: e]; }
- (void)rightMouseDown:(NSEvent *)e { if (GS(self)->buttonMask & 2) [self wsdDown: e]; } - (void)rightMouseDragged:(NSEvent *)e { if (GS(self)->buttonMask & 2) [self wsdDrag: e]; } - (void)rightMouseUp:(NSEvent *)e { if (GS(self)->buttonMask & 2) [self wsdUp: e]; }
- (void)reset { WsdGS *g = GS(self); g->state = GRPossible; g->translation = NSZeroPoint; g->velocity = NSZeroPoint; }
@end

@implementation NSPressGestureRecognizer (WsdGesture)
- (NSInteger)buttonMask { return GS(self)->buttonMask; } - (void)setButtonMask:(NSInteger)m { GS(self)->buttonMask = m; }
- (NSTimeInterval)minimumPressDuration { return GS(self)->minDuration; } - (void)setMinimumPressDuration:(NSTimeInterval)d { GS(self)->minDuration = d; }
- (CGFloat)allowableMovement { return GS(self)->allowable; } - (void)setAllowableMovement:(CGFloat)m { GS(self)->allowable = m; }
- (NSInteger)numberOfTouchesRequired { return 1; } - (void)setNumberOfTouchesRequired:(NSInteger)n {}
- (void)wsdFire:(NSTimer *)t { WsdGS *g = GS(self); g->timer = nil; if (g->state == GRPossible) [self setState: GRBegan]; }
- (void)mouseDown:(NSEvent *)e
{
	WsdGS *g = GS(self); if (!(g->buttonMask & 1)) return; g->start = g->last = [e locationInWindow];
	[g->timer invalidate]; g->timer = [NSTimer timerWithTimeInterval: g->minDuration target: self selector: @selector(wsdFire:) userInfo: nil repeats: NO];
	for (NSString *m in [NSArray arrayWithObjects: NSDefaultRunLoopMode, NSEventTrackingRunLoopMode, NSModalPanelRunLoopMode, nil]) [[NSRunLoop currentRunLoop] addTimer: g->timer forMode: m];
}
- (void)mouseDragged:(NSEvent *)e
{
	WsdGS *g = GS(self); g->last = [e locationInWindow];
	if (g->state == GRPossible && Dist(g->start, g->last) > g->allowable) { [g->timer invalidate]; g->timer = nil; Fail(self); }
	else if (g->state == GRBegan || g->state == GRChanged) [self setState: GRChanged];
}
- (void)mouseUp:(NSEvent *)e
{
	WsdGS *g = GS(self); g->last = [e locationInWindow]; [g->timer invalidate]; g->timer = nil;
	if (g->state == GRBegan || g->state == GRChanged) [self setState: GREnded]; else if (g->state == GRPossible) Fail(self);
}
- (void)reset { WsdGS *g = GS(self); [g->timer invalidate]; g->timer = nil; g->state = GRPossible; }
@end

/* the view's recognizers */
@implementation NSView (WsdGestures)
- (NSArray *)gestureRecognizers { NSArray *a = objc_getAssociatedObject(self, &kList); return a ? a : [NSArray array]; }
- (void)setGestureRecognizers:(NSArray *)g { for (id r in [NSArray arrayWithArray: [self gestureRecognizers]]) [self removeGestureRecognizer: r]; for (id r in g) [self addGestureRecognizer: r]; }
- (void)addGestureRecognizer:(NSGestureRecognizer *)g
{
	NSMutableArray *m = [NSMutableArray arrayWithArray: [self gestureRecognizers]]; if ([m containsObject: g]) return;
	if (GS(g)->view) [GS(g)->view removeGestureRecognizer: g];
	[m addObject: g]; objc_setAssociatedObject(self, &kList, m, OBJC_ASSOCIATION_RETAIN_NONATOMIC); GS(g)->view = self;
}
- (void)removeGestureRecognizer:(NSGestureRecognizer *)g
{
	NSMutableArray *m = [NSMutableArray arrayWithArray: [self gestureRecognizers]]; if (![m containsObject: g]) return;
	[g retain]; [m removeObject: g]; objc_setAssociatedObject(self, &kList, m, OBJC_ASSOCIATION_RETAIN_NONATOMIC); GS(g)->view = nil; [g release];
}
@end

/* the window feeds the recognizers and holds the view's events while one may still recognize */
static IMP origSend; static BOOL replaying;
static BOOL Delays(NSGestureRecognizer *g, NSInteger bit) { WsdGS *s = GS(g); return bit == 1 ? s->delaysPrimary : bit == 2 ? s->delaysSecondary : s->delaysOther; }
static void Feed(NSGestureRecognizer *g, NSEvent *e)
{
	switch ([e type])
	{
	case NSLeftMouseDown: [g mouseDown: e]; break; case NSLeftMouseDragged: [g mouseDragged: e]; break; case NSLeftMouseUp: [g mouseUp: e]; break;
	case NSRightMouseDown: [g rightMouseDown: e]; break; case NSRightMouseDragged: [g rightMouseDragged: e]; break; case NSRightMouseUp: [g rightMouseUp: e]; break;
	case NSOtherMouseDown: [g otherMouseDown: e]; break; case NSOtherMouseDragged: [g otherMouseDragged: e]; break; case NSOtherMouseUp: [g otherMouseUp: e]; break;
	default: break;
	}
}
static void Replay(NSWindow *w)
{
	NSMutableArray *q = objc_getAssociatedObject(w, &kQueue); if (![q count]) return;
	NSArray *ev = [[q copy] autorelease]; [q removeAllObjects]; replaying = YES;
	for (NSEvent *e in ev) ((void (*)(id, SEL, id))origSend)(w, @selector(sendEvent:), e);
	replaying = NO;
}
static void EndSequence(NSWindow *w)
{
	NSArray *act = objc_getAssociatedObject(w, &kActive);
	for (NSGestureRecognizer *g in act) { if (GS(g)->state != GRPossible) { [g reset]; } }
	objc_setAssociatedObject(w, &kActive, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
@interface NSWindow (WsdGestureTimer) - (void)wsdGestureTimeout:(NSTimer *)t; @end
@implementation NSWindow (WsdGestureTimer)
/* a double-click recognizer waits for the second click: when it does not come the recognizers that are still Possible fail and the view gets its events */
- (void)wsdGestureTimeout:(NSTimer *)t
{
	for (NSGestureRecognizer *g in objc_getAssociatedObject(self, &kActive)) if (GS(g)->state == GRPossible) Fail(g);
	Replay(self); EndSequence(self);
}
@end
static void wsdWindowSend(NSWindow *self, SEL _cmd, NSEvent *e)
{
	NSEventType t = [e type];
	if (replaying || !(IsDown(e) || IsUp(e) || IsDrag(e))) { ((void (*)(id, SEL, id))origSend)(self, _cmd, e); return; }
	NSInteger bit = ButtonBit(e);
	if (IsDown(e))
	{
		EndSequence(self); objc_setAssociatedObject(self, &kQueue, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		NSMutableArray *act = [NSMutableArray array]; NSView *hit = [[[self contentView] superview] hitTest: [e locationInWindow]] ?: [self contentView];
		for (NSView *v = hit; v; v = [v superview]) for (NSGestureRecognizer *g in [v gestureRecognizers])
			if (GS(g)->enabled && !([GS(g)->delegate respondsToSelector: @selector(gestureRecognizer:shouldAttemptToRecognizeWithEvent:)] && ![GS(g)->delegate gestureRecognizer: g shouldAttemptToRecognizeWithEvent: e])) { GS(g)->state = GRPossible; [act addObject: g]; }
		objc_setAssociatedObject(self, &kActive, act, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	NSArray *act = objc_getAssociatedObject(self, &kActive);
	if (![act count]) { ((void (*)(id, SEL, id))origSend)(self, _cmd, e); return; }
	[NSObject cancelPreviousPerformRequestsWithTarget: self selector: @selector(wsdGestureTimeout:) object: nil];
	BOOL hold = NO, consumed = NO, possible = NO;
	for (NSGestureRecognizer *g in act) { if (GS(g)->state != GRFailed && GS(g)->state != GRCancelled) Feed(g, e); }
	for (NSGestureRecognizer *g in act)
	{
		NSInteger st = GS(g)->state;
		if (st == GRBegan || st == GRChanged || st == GREnded) consumed = consumed || Delays(g, bit);
		if (st == GRPossible) { possible = YES; hold = hold || Delays(g, bit); }
	}
	NSMutableArray *q = objc_getAssociatedObject(self, &kQueue); if (!q) { q = [NSMutableArray array]; objc_setAssociatedObject(self, &kQueue, q, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
	if (consumed) { [q removeAllObjects]; objc_setAssociatedObject(self, &kQueue, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }       /* recognized: the view never sees it */
	else if (hold) { [q addObject: e]; if (IsUp(e)) [self performSelector: @selector(wsdGestureTimeout:) withObject: nil afterDelay: [NSEvent doubleClickInterval]]; }
	else { Replay(self); ((void (*)(id, SEL, id))origSend)(self, _cmd, e); }
	(void)t; (void)possible;
	if (IsUp(e) && !hold) EndSequence(self);
	else if (IsUp(e) && hold && !possible) { Replay(self); EndSequence(self); }
}
@interface WsdGestureInit : NSObject @end
@implementation WsdGestureInit
+ (void)load { Method m = class_getInstanceMethod([NSWindow class], @selector(sendEvent:)); if (m) { origSend = method_getImplementation(m); class_replaceMethod([NSWindow class], @selector(sendEvent:), (IMP)wsdWindowSend, method_getTypeEncoding(m)); } }
@end
