/* Gesture recognizers: click (delays the view's events, consumes them on success, replays them on failure), pan states and translation, press timer, double-click. */
#import <AppKit/AppKit.h>
@interface NSGestureRecognizer (D) - (id)initWithTarget:(id)t action:(SEL)a; - (NSInteger)state; - (NSPoint)locationInView:(NSView *)v; - (void)setDelaysPrimaryMouseButtonEvents:(BOOL)b; @end
@interface NSView (D) - (void)addGestureRecognizer:(id)g; - (NSArray *)gestureRecognizers; - (void)removeGestureRecognizer:(id)g; @end
@interface NSClickGestureRecognizer (D) - (void)setNumberOfClicksRequired:(NSInteger)n; @end
@interface NSPanGestureRecognizer (D) - (NSPoint)translationInView:(NSView *)v; @end
@interface NSPressGestureRecognizer (D) - (void)setMinimumPressDuration:(NSTimeInterval)d; @end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
@interface V : NSView { @public int downs, ups, drags; } @end
@implementation V - (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; } - (void)mouseDown:(NSEvent *)e { downs++; } - (void)mouseUp:(NSEvent *)e { ups++; } - (void)mouseDragged:(NSEvent *)e { drags++; } @end
@interface T : NSObject { @public int fired; NSInteger lastState; } - (void)act:(id)g; @end
@implementation T - (void)act:(id)g { fired++; lastState = [g state]; } @end
static NSTimeInterval now = 1;
static void ev(NSWindow *w, NSEventType t, NSPoint p, int clicks)
{
	now += 0.01;
	[w sendEvent: [NSEvent mouseEventWithType: t location: p modifierFlags: 0 timestamp: now windowNumber: [w windowNumber] context: nil eventNumber: 0 clickCount: clicks pressure: 1]];
}
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, 300, 200) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		V *v = [[V alloc] initWithFrame: NSMakeRect(0, 0, 300, 200)]; [w setContentView: v]; [w makeKeyAndOrderFront: nil];
		T *t = [[T alloc] init];
		id click = [[NSClickGestureRecognizer alloc] initWithTarget: t action: @selector(act:)]; [v addGestureRecognizer: click];
		CHECK([[v gestureRecognizers] count] == 1);
		ev(w, NSLeftMouseDown, NSMakePoint(50, 50), 1); CHECK(v->downs == 0);
		ev(w, NSLeftMouseUp, NSMakePoint(50, 50), 1); CHECK(t->fired == 1); CHECK(t->lastState == 3); CHECK(v->downs == 0 && v->ups == 0);
		ev(w, NSLeftMouseDown, NSMakePoint(50, 50), 1); ev(w, NSLeftMouseDragged, NSMakePoint(120, 50), 1); ev(w, NSLeftMouseUp, NSMakePoint(120, 50), 1);
		CHECK(t->fired == 1); CHECK(v->downs == 1); CHECK(v->drags == 1); CHECK(v->ups == 1);
		[click setDelaysPrimaryMouseButtonEvents: NO]; v->downs = v->ups = 0;
		ev(w, NSLeftMouseDown, NSMakePoint(50, 50), 1); CHECK(v->downs == 1); ev(w, NSLeftMouseUp, NSMakePoint(50, 50), 1); CHECK(t->fired == 2);
		[v removeGestureRecognizer: click]; CHECK([[v gestureRecognizers] count] == 0);
		T *t2 = [[T alloc] init]; id pan = [[NSPanGestureRecognizer alloc] initWithTarget: t2 action: @selector(act:)]; [v addGestureRecognizer: pan];
		ev(w, NSLeftMouseDown, NSMakePoint(10, 10), 1); ev(w, NSLeftMouseDragged, NSMakePoint(12, 10), 1); CHECK(t2->fired == 0);
		ev(w, NSLeftMouseDragged, NSMakePoint(40, 30), 1); CHECK(t2->fired == 1);
		NSPoint tr = [pan translationInView: v]; CHECK(fabs(tr.x - 30) < 0.5 && fabs(tr.y - 20) < 0.5);
		ev(w, NSLeftMouseDragged, NSMakePoint(60, 30), 1); CHECK(t2->fired == 2); ev(w, NSLeftMouseUp, NSMakePoint(60, 30), 1); CHECK(t2->fired == 3); CHECK(t2->lastState == 3);
		[v removeGestureRecognizer: pan];
		T *t3 = [[T alloc] init]; id press = [[NSPressGestureRecognizer alloc] initWithTarget: t3 action: @selector(act:)]; [press setMinimumPressDuration: 0.1]; [v addGestureRecognizer: press];
		ev(w, NSLeftMouseDown, NSMakePoint(10, 10), 1); [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.3]]; CHECK(t3->fired == 1 && t3->lastState == 1);
		ev(w, NSLeftMouseUp, NSMakePoint(10, 10), 1); CHECK(t3->fired == 2 && t3->lastState == 3);
		[v removeGestureRecognizer: press];
		T *t4 = [[T alloc] init]; id dbl = [[NSClickGestureRecognizer alloc] initWithTarget: t4 action: @selector(act:)]; [dbl setNumberOfClicksRequired: 2]; [v addGestureRecognizer: dbl];
		v->downs = v->ups = 0;
		ev(w, NSLeftMouseDown, NSMakePoint(20, 20), 1); ev(w, NSLeftMouseUp, NSMakePoint(20, 20), 1); CHECK(t4->fired == 0); CHECK(v->downs == 0);
		ev(w, NSLeftMouseDown, NSMakePoint(20, 20), 2); ev(w, NSLeftMouseUp, NSMakePoint(20, 20), 2); CHECK(t4->fired == 1); CHECK(v->downs == 0);
		ev(w, NSLeftMouseDown, NSMakePoint(20, 20), 1); ev(w, NSLeftMouseUp, NSMakePoint(20, 20), 1); CHECK(t4->fired == 1);
		[[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: [NSEvent doubleClickInterval] + 0.3]];
		CHECK(v->downs == 1 && v->ups == 1);
	}
	printf(fails ? "gesture: %d failed\n" : "gesture ok\n", fails);
	return fails != 0;
}
