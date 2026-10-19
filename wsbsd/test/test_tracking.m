/* NSTrackingArea: enter / exit reach the owner according to the options, event.trackingArea is the area, in-visible-rect areas follow the view, removal stops delivery. */
#import <AppKit/AppKit.h>
@interface NSView (WsdTrackingDecl)
- (NSArray *)trackingAreas; - (void)addTrackingArea:(NSTrackingArea *)a; - (void)removeTrackingArea:(NSTrackingArea *)a;
@end
@interface NSEvent (WsdTrackingDecl)
- (NSTrackingArea *)trackingArea;
@end
static int fails;
#define CHECK(c) do { if (!(c)) { printf("FAIL %s:%d %s\n", __FILE__, __LINE__, #c); fails++; } } while (0)
@interface Owner : NSView { @public int in, out, cur; NSTrackingArea *last; } @end
@implementation Owner
- (void)mouseEntered:(NSEvent *)e { in++; last = [e trackingArea]; }
- (void)mouseExited:(NSEvent *)e { out++; }
- (void)cursorUpdate:(NSEvent *)e { cur++; }
@end
static void move(NSWindow *w, NSPoint p)
{
	[w sendEvent: [NSEvent mouseEventWithType: NSMouseMoved location: p modifierFlags: 0 timestamp: 0 windowNumber: [w windowNumber] context: nil eventNumber: 0 clickCount: 0 pressure: 0]];
}
int main(void)
{
	@autoreleasepool {
		[NSApplication sharedApplication];
		NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(100, 100, 300, 200) styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: NO];
		Owner *v = [[Owner alloc] initWithFrame: NSMakeRect(50, 50, 100, 100)];
		[[w contentView] addSubview: v];
		[w orderFront: nil]; [w makeKeyWindow];
		NSTrackingArea *a = [[NSTrackingArea alloc] initWithRect: NSMakeRect(0, 0, 100, 100) options: NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways owner: v userInfo: nil];
		CHECK([[v trackingAreas] count] == 0);
		[v addTrackingArea: a];
		CHECK([[v trackingAreas] count] == 1);
		move(w, NSMakePoint(10, 10)); CHECK(v->in == 0);
		move(w, NSMakePoint(60, 60)); CHECK(v->in == 1); CHECK(v->last == a);
		move(w, NSMakePoint(70, 70)); CHECK(v->in == 1);
		move(w, NSMakePoint(200, 150)); CHECK(v->out == 1);
		[v removeTrackingArea: a];
		move(w, NSMakePoint(60, 60)); CHECK(v->in == 1);
		NSTrackingArea *b = [[NSTrackingArea alloc] initWithRect: NSZeroRect options: NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect owner: v userInfo: nil];
		[v addTrackingArea: b];
		move(w, NSMakePoint(200, 150));
		move(w, NSMakePoint(60, 60)); CHECK(v->in == 2);
		[v setFrame: NSMakeRect(150, 50, 100, 100)];
		move(w, NSMakePoint(60, 60)); CHECK(v->out == 2);
		move(w, NSMakePoint(160, 60)); CHECK(v->in == 3);
	}
	printf(fails ? "tracking: %d failed\n" : "tracking ok\n", fails);
	return fails != 0;
}
