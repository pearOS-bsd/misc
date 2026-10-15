#include "config.h"

#include <AppKit/NSApplication.h>
#include <AppKit/NSEvent.h>
#include <AppKit/NSWindow.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSValue.h>
#include <GNUstepGUI/GSDisplayServer.h>
#include <AppKit/NSWindow.h>
#include <signal.h>

#include "wsd/WsdServer.h"
#define WLOG(...) do { if (getenv("WSD_DEBUG")) NSLog(@"wsd-back: " __VA_ARGS__); } while (0)
#include "wsd/WsdCairoSurface.h"

/* CGKeyCode -> characters for an ANSI layout (unshifted, shifted) */
static const char *keymap[128][2] = {
	[0]={"a","A"},[1]={"s","S"},[2]={"d","D"},[3]={"f","F"},[4]={"h","H"},[5]={"g","G"},[6]={"z","Z"},[7]={"x","X"},[8]={"c","C"},[9]={"v","V"},
	[11]={"b","B"},[12]={"q","Q"},[13]={"w","W"},[14]={"e","E"},[15]={"r","R"},[16]={"y","Y"},[17]={"t","T"},[18]={"1","!"},[19]={"2","@"},
	[20]={"3","#"},[21]={"4","$"},[22]={"6","^"},[23]={"5","%"},[24]={"=","+"},[25]={"9","("},[26]={"7","&"},[27]={"-","_"},[28]={"8","*"},
	[29]={"0",")"},[30]={"]","}"},[31]={"o","O"},[32]={"u","U"},[33]={"[","{"},[34]={"i","I"},[35]={"p","P"},[36]={"\r","\r"},[37]={"l","L"},
	[38]={"j","J"},[39]={"'","\""},[40]={"k","K"},[41]={";",":"},[42]={"\\","|"},[43]={",","<"},[44]={"/","?"},[45]={"n","N"},[46]={"m","M"},
	[47]={".",">"},[48]={"\t","\t"},[49]={" "," "},[50]={"`","~"},[51]={"\x7f","\x7f"},[53]={"\x1b","\x1b"},
};

static NSString *keychars(int code, unsigned flags, BOOL ignoringMods)
{
	if (code < 0 || code >= 128) return @"";
	int shift = (flags & 0x20000) != 0;          /* kCGEventFlagMaskShift */
	const char *s = keymap[code][(shift && !ignoringMods) ? 1 : 0];
	return s ? [NSString stringWithUTF8String: s] : @"";
}

static unsigned nsflags(uint32_t f)
{
	unsigned r = 0;
	if (f & 0x20000) r |= NSShiftKeyMask;
	if (f & 0x40000) r |= NSControlKeyMask;
	if (f & 0x80000) r |= NSAlternateKeyMask;
	if (f & 0x100000) r |= NSCommandKeyMask;
	return r;
}

static void terminate(int sig)
{
	if (nil != NSApp) [NSApp terminate: NSApp]; else exit(1);
}

@implementation WsdServer

+ (void) initializeBackend
{
	NSDebugLog(@"Initializing GNUstep wsd backend.\n");
	[GSDisplayServer setDefaultServerClass: [WsdServer class]];
	signal(SIGTERM, terminate);
	signal(SIGINT, terminate);
}

- (id) initWithAttributes: (NSDictionary *)attributes
{
	self = [super initWithAttributes: attributes];
	if (self == nil) return nil;
	conn = ws_connect(NULL);
	if (conn == NULL) {
		NSLog(@"wsd backend: cannot connect to the window server (WS_SOCKET=%s)", getenv("WS_SOCKET") ? getenv("WS_SOCKET") : "default");
		[self release];
		return nil;
	}
	if (ws_conn_screen(conn, &screenW, &screenH)) { screenW = 1280; screenH = 800; }
	int fd = ws_conn_event_fd(conn);
	WLOG(@"event fd %d", fd);
	NSRunLoop *rl = [NSRunLoop currentRunLoop];
	NSString *modes[] = { NSDefaultRunLoopMode, NSModalPanelRunLoopMode, NSEventTrackingRunLoopMode };
	for (int i = 0; i < 3; i++)
		[rl addEvent: (void *)(intptr_t)fd type: ET_RDESC watcher: (id)self forMode: modes[i]];
	return self;
}

- (ws_conn *) connection { return conn; }

- (struct wsd_window *) wsdWindow: (int)number
{
	for (struct wsd_window *w = windows; w; w = w->next) if (w->number == number) return w;
	return NULL;
}

/* wsd has no window manager: AppKit draws its own title bars and borders (client-side decorations) and moves/resizes the window itself */
- (BOOL) handlesWindowDecorations { return NO; }

/* ---- screen ---- */
- (NSArray *) screenList { return [NSArray arrayWithObject: [NSNumber numberWithInt: 0]]; }
- (NSRect) boundsForScreen: (int)screen { return NSMakeRect(0, 0, screenW, screenH); }
- (NSWindowDepth) windowDepthForScreen: (int)screen { return (NSWindowDepth)(0x100 | 8); }
- (NSSize) resolutionForScreen: (int)screen { return NSMakeSize(72, 72); }
- (void) styleoffsets: (float *)l : (float *)r : (float *)t : (float *)b : (unsigned int)style
{
	*l = *r = *t = *b = 0;
}
- (void) standardcursor: (int)style : (void **)cid { *cid = NULL; }
- (void) imagecursor: (NSPoint)hotp : (NSImage *)image : (void **)cid { *cid = NULL; }
- (void) setcursor: (void *)cid {}

/* ---- windows ---- */
- (int) window: (NSRect)frame : (NSBackingStoreType)type : (unsigned int)style : (int)screen
{
	if (frame.size.width < 1) frame.size.width = 1;
	if (frame.size.height < 1) frame.size.height = 1;
	struct wsd_window *w = calloc(1, sizeof *w);
	w->w = (int)frame.size.width; w->h = (int)frame.size.height;
	w->x = (int)frame.origin.x; w->y = screenH - (int)(frame.origin.y + frame.size.height);
	w->style = style;
	if (ws_win_create(conn, (ws_rect){ w->x, w->y, w->w, w->h }, 0, &w->win)) { free(w); return 0; }
	w->number = (int)w->win.id;
	WLOG(@"window %d created %d,%d %dx%d style %x", w->number, w->x, w->y, w->w, w->h, style);
	w->next = windows; windows = w;
	[self _setWindowOwnedByServer: w->number];   /* without this GSServerForWindow() is nil for the window and AppKit's calls never arrive */
	return w->number;
}

- (BOOL) attachBuffer: (struct wsd_window *)w
{
	if (w->has_buffer && w->cbuf.buf.w == w->w && w->cbuf.buf.h == w->h) return YES;
	if (w->has_buffer) {
		ws_surface_unbind(conn, &w->win, w->sid);
		ws_surface_remove(conn, &w->win, w->sid);
		ws_cbuf_release(conn, &w->cbuf);
		w->has_buffer = 0;
	}
	WLOG(@"attachBuffer %d %dx%d", w->number, w->w, w->h);
	if (ws_cbuf_create(conn, w->w, w->h, &w->cbuf)) { WLOG(@"cbuf_create failed"); return NO; }
	if (ws_surface_add(conn, &w->win, &w->sid) || ws_surface_bind_buffer(conn, &w->win, w->sid, &w->cbuf)) { ws_cbuf_release(conn, &w->cbuf); return NO; }
	w->has_buffer = 1;
	return YES;
}

- (void) commitWindow: (struct wsd_window *)w rect: (NSRect)rect
{
	if (!w->has_buffer) return;
	/* NSRect is in the window's flipped-for-Cairo space of the drawing; flush the whole surface: partial rects from AppKit are in the bottom-left space */
	(void)rect;
	int frc = ws_surface_flush(conn, &w->win, w->sid, NULL);
	WLOG(@"commit %d -> %d", w->number, frc);
}

- (void) termwindow: (int)win
{
	struct wsd_window **pp = &windows;
	while (*pp && (*pp)->number != win) pp = &(*pp)->next;
	struct wsd_window *w = *pp;
	if (!w) return;
	*pp = w->next;
	if (w->has_buffer) { ws_surface_unbind(conn, &w->win, w->sid); ws_surface_remove(conn, &w->win, w->sid); ws_cbuf_release(conn, &w->cbuf); }
	ws_win_release(conn, &w->win);
	free(w);
}

- (void) setWindowdevice: (int)win forContext: (NSGraphicsContext *)ctxt
{
	struct wsd_window *w = [self wsdWindow: win];
	WLOG(@"setWindowdevice %d %p", win, w);
	if (!w) return;
	[ctxt GSSetDevice: w : 0 : w->h];
	[ctxt DPSinitmatrix];
	[ctxt DPSinitclip];
}

- (void) orderwindow: (int)op : (int)otherWin : (int)win
{
	WLOG(@"orderwindow enter %d op %d other %d", win, op, otherWin);
	struct wsd_window *w = [self wsdWindow: win];
	if (!w) return;
	WLOG(@"orderwindow %d op %d", win, op);
	int mode = op == NSWindowOut ? WS_OUT : (op == NSWindowBelow ? WS_BELOW : WS_ABOVE);
	int orc = ws_win_order(conn, &w->win, mode, (ws_wid)otherWin);
	WLOG(@"ws_win_order -> %d", orc);
	if (mode != WS_OUT && w->has_buffer) ws_surface_flush(conn, &w->win, w->sid, NULL);
}

- (void) flushwindowrect: (NSRect)rect : (int)win
{
	WLOG(@"flushwindowrect enter %d", win);
	struct wsd_window *w = [self wsdWindow: win];
	WLOG(@"flushwindowrect %d surface %p", win, w ? w->surface : NULL);
	if (w) [[GSCurrentContext() class] handleExposeRect: rect forDriver: w->surface];
}

- (NSRect) windowbounds: (int)win
{
	struct wsd_window *w = [self wsdWindow: win];
	if (!w) return NSZeroRect;
	return NSMakeRect(w->x, screenH - (w->y + w->h), w->w, w->h);
}

/* AppKit updates NSWindow's frame only when the backend reports it: moved/resized events, in AppKit coordinates (origin bottom-left) */
- (void) reportFrameOf: (struct wsd_window *)w resized: (BOOL)resized
{
	NSPoint origin = NSMakePoint(w->x, screenH - (w->y + w->h));
	NSTimeInterval ts = [[NSDate date] timeIntervalSinceReferenceDate];
	NSEvent *ev = [NSEvent otherEventWithType: NSAppKitDefined location: resized ? origin : NSZeroPoint modifierFlags: 0 timestamp: ts windowNumber: w->number context: GSCurrentContext()
		subtype: resized ? GSAppKitWindowResized : GSAppKitWindowMoved data1: resized ? w->w : (NSInteger)origin.x data2: resized ? w->h : (NSInteger)origin.y];
	[NSApp postEvent: ev atStart: NO];   /* queued: the NSWindow may not be fully set up yet while it is being created */
}

- (void) placewindow: (NSRect)frame : (int)win
{
	struct wsd_window *w = [self wsdWindow: win];
	if (!w) return;
	int nw = (int)frame.size.width, nh = (int)frame.size.height;
	if (nw < 1) nw = 1;
	if (nh < 1) nh = 1;
	w->x = (int)frame.origin.x; w->y = screenH - (int)(frame.origin.y + frame.size.height);
	BOOL resized = (nw != w->w || nh != w->h);
	WLOG(@"placewindow %d -> %d,%d %dx%d resized %d", win, w->x, w->y, nw, nh, (int)resized);
	w->w = nw; w->h = nh;
	ws_win_set_frame(conn, &w->win, (ws_rect){ w->x, w->y, w->w, w->h });
	/* the old buffer stays mapped (the current Cairo surface still draws into it); the next setWindowdevice:forContext: sees the size change in attachBuffer: and swaps it */
	[self reportFrameOf: w resized: resized];
}

- (void) movewindow: (NSPoint)loc : (int)win
{
	struct wsd_window *w = [self wsdWindow: win];
	if (!w) return;
	w->x = (int)loc.x; w->y = screenH - (int)(loc.y + w->h);
	ws_win_move(conn, &w->win, w->x, w->y);
	[self reportFrameOf: w resized: NO];
}

- (void) setwindowlevel: (int)level : (int)win
{
	struct wsd_window *w = [self wsdWindow: win];
	if (w) { w->level = level; ws_win_set_level(conn, &w->win, level); }
}
- (int) windowlevel: (int)win { struct wsd_window *w = [self wsdWindow: win]; return w ? w->level : 0; }
- (int) windowdepth: (int)win { return (int)(0x100 | 8); }
- (void) titlewindow: (NSString *)window_title : (int)win { WLOG(@"titlewindow %d", win); }
- (void) miniwindow: (int)win {}
- (BOOL) appOwnsMiniwindow { return NO; }
- (void) setinputfocus: (int)win { WLOG(@"setinputfocus %d", win); keyWindow = win; }
- (void) setalpha: (float)alpha : (int)win
{
	struct wsd_window *w = [self wsdWindow: win];
	if (w) ws_win_alpha(conn, &w->win, alpha);
}
- (void) setShadow: (BOOL)hasShadow : (int)win
{
	struct wsd_window *w = [self wsdWindow: win];
	if (w) ws_win_shadow(conn, &w->win, 10, hasShadow);
}
- (BOOL) hasShadow: (int)win { return YES; }
- (void) setMinimumSize: (NSSize)size : (int)win {}
- (void) setMaximumSize: (NSSize)size : (int)win {}
- (void) setResizeIncrements: (NSSize)size : (int)win {}
- (void) setWindowdevice: (int)win {}
- (void) docedited: (int)edited : (int)win {}
- (NSPoint) mouseLocationOnScreen: (int)screen window: (int *)win
{
	if (win) *win = 0;
	return lastPoint;
}
- (BOOL) capturemouse: (int)win { return YES; }
- (void) releasemouse {}
- (void) setParentWindow: (int)parentWin forChildWindow: (int)childWin {}

/* ---- events ---- */
- (void) receivedEvent: (void *)data type: (RunLoopEventType)type extra: (void *)extra forMode: (NSString *)mode
{
	ws_event e;
	WLOG(@"receivedEvent called");
	while (ws_conn_next_pushed_event(conn, 0, &e)) {
		WLOG(@"event type %d wid %d at %d,%d buttons %d", e.type, (int)e.wid, e.x, e.y, e.buttons);
		struct wsd_window *w = [self wsdWindow: (int)e.wid];
		if (!w) continue;
		NSPoint p = NSMakePoint(e.x, w->h - e.y);
		NSEventType t;
		NSUInteger fl = nsflags(e.flags);
		NSEvent *ev = nil;
		NSTimeInterval ts = [[NSDate date] timeIntervalSinceReferenceDate];
		lastPoint = NSMakePoint(w->x + e.x, screenH - (w->y + e.y));
		switch (e.type) {
		case WS_EV_MOUSE_MOVE:
			t = (e.buttons & 1) ? NSLeftMouseDragged : ((e.buttons & 2) ? NSRightMouseDragged : NSMouseMoved);
			ev = [NSEvent mouseEventWithType: t location: p modifierFlags: fl timestamp: ts windowNumber: w->number context: GSCurrentContext() eventNumber: 0 clickCount: 1 pressure: 1.0];
			break;
		case WS_EV_MOUSE_DOWN:
		case WS_EV_MOUSE_UP: {
			BOOL down = e.type == WS_EV_MOUSE_DOWN;
			t = (e.buttons & 2) ? (down ? NSRightMouseDown : NSRightMouseUp) : (down ? NSLeftMouseDown : NSLeftMouseUp);
			ev = [NSEvent mouseEventWithType: t location: p modifierFlags: fl timestamp: ts windowNumber: w->number context: GSCurrentContext() eventNumber: 0 clickCount: 1 pressure: down ? 1.0 : 0.0];
			break; }
		case WS_EV_KEY_DOWN:
		case WS_EV_KEY_UP:
			ev = [NSEvent keyEventWithType: e.type == WS_EV_KEY_DOWN ? NSKeyDown : NSKeyUp location: p modifierFlags: fl timestamp: ts windowNumber: w->number context: GSCurrentContext()
				characters: keychars(e.key, e.flags, NO) charactersIgnoringModifiers: keychars(e.key, e.flags, YES) isARepeat: NO keyCode: (unsigned short)e.key];
			break;
		case WS_EV_SCROLL:
			ev = [NSEvent otherEventWithType: NSScrollWheel location: p modifierFlags: fl timestamp: ts windowNumber: w->number context: GSCurrentContext() subtype: 0 data1: e.dx data2: e.dy];
			break;
		case WS_EV_FOCUS_IN:
			ev = [NSEvent otherEventWithType: NSAppKitDefined location: NSZeroPoint modifierFlags: 0 timestamp: ts windowNumber: w->number context: GSCurrentContext() subtype: GSAppKitWindowFocusIn data1: 0 data2: 0];
			break;
		case WS_EV_FOCUS_OUT:
			ev = [NSEvent otherEventWithType: NSAppKitDefined location: NSZeroPoint modifierFlags: 0 timestamp: ts windowNumber: w->number context: GSCurrentContext() subtype: GSAppKitWindowFocusOut data1: 0 data2: 0];
			break;
		default: break;
		}
		if (ev) [NSApp postEvent: ev atStart: NO];
	}
}

- (NSDate *) timedOutEvent: (void *)data type: (RunLoopEventType)type forMode: (NSString *)mode { return nil; }


/* ---- the rest of what GSDisplayServer expects a backend to override ---- */
- (void) restrictWindow: (int)win toImage: (NSImage *)image {}
- (int) findWindowAt: (NSPoint)screenLocation windowRef: (int *)windowRef excluding: (int)win
{
	ws_wid f = ws_win_find(conn, (int)screenLocation.x, screenH - (int)screenLocation.y);
	if (windowRef) *windowRef = (int)f;
	return (int)f;
}
- (const NSWindowDepth *) availableDepthsForScreen: (int)screen
{
	static NSWindowDepth depths[2];
	depths[0] = (NSWindowDepth)(0x100 | 8); depths[1] = 0;
	return depths;
}
- (void *) serverDevice { return conn; }
- (void *) windowDevice: (int)win { return [self wsdWindow: win]; }
- (void) beep {}
- (int) nativeWindow: (void *)winref : (NSRect *)frame : (NSBackingStoreType *)type : (unsigned int *)style : (int *)screen { return 0; }
- (void) stylewindow: (unsigned int)style : (int)win { struct wsd_window *w = [self wsdWindow: win]; if (w) w->style = style; }
- (void) windowbacking: (NSBackingStoreType)type : (int)win {}
- (void) setmaxsize: (NSSize)size : (int)win {}
- (void) setminsize: (NSSize)size : (int)win {}
- (void) setresizeincrements: (NSSize)size : (int)win {}
- (void) setinputstate: (int)state : (int)win { WLOG(@"setinputstate %d %d", state, win); }
- (NSPoint) mouselocation { return lastPoint; }
- (void) setMouseLocation: (NSPoint)mouseLocation onScreen: (int)aScreen { ws_cursor_warp(conn, (int)mouseLocation.x, screenH - (int)mouseLocation.y, 0); lastPoint = mouseLocation; }
- (void) hidecursor {}
- (void) showcursor {}
- (void) recolorcursor: (NSColor *)fg : (NSColor *)bg : (void *)cid {}
- (void) freecursor: (void *)cid {}

@end
