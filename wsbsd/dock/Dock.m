/* Dock.app for wsbsd: the Dock of the desktop. A borderless window at the bottom of the screen draws the bar with DockRender; the layout (with magnification) comes from dock_layout.c, the genie from genie.c.
 * The items are the persistent applications of ~/Library/Preferences/com.apple.dock.plist (or a default set), the running ones get a dot. */
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#include <unistd.h>
#include <signal.h>
#include "DockRender.h"
#include "genie.h"
#include "ws_client.h"
#import "../launchservices/LSIcon.h"

#define MAXITEMS 64
static double Now(void) { return CACurrentMediaTime(); }

/* a minimized window: lives in the Dock as a tile with its picture; the genie runs between the window and the tile */
typedef struct { uint32_t wid; int pid; char label[64]; CGImageRef thumb; int phase; double t0; double wr[4]; int item; int appItem; } MiniWin;       /* phase: 1 minimizing, 2 settled, 3 restoring */
#define MAXMINI 16

@interface DockView : NSView {
@public
	ws_rect glassRect; int glassOn;
	NSString *fanDir; double fanMTime, fanCheck;      /* the folder of the open fan and its modification time: the fan lists it again when it changes */
	double winX, winW;     /* the bar's window: as wide as the bar gets when magnified, fixed for the current items (resizing the window every frame made the Dock flicker) */
	MiniWin mini[MAXMINI]; int nmini; ws_conn *wsc; float genieMesh[GENIE_MAX_FLOATS];
	DockMetrics m; DockItem items[MAXITEMS]; DockTile tiles[MAXITEMS]; DockSlot slots[MAXITEMS]; DockBar bar; int n;
	NSMutableArray *paths; NSMutableArray *names; NSMutableArray *pids; NSMutableArray *labelStore;
	NSTrackingRectTag trackTag; double pointer; int hover; double scale[MAXITEMS]; double bounceStart[MAXITEMS]; NSTimer *timer; double screenW, screenH; DockFan fan; int fanOpen; double fanStart, fanClose; NSMutableArray *fanStore;
}
- (void)reload;
@end

@implementation DockView
- (BOOL)isFlipped { return NO; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (instancetype)initWithFrame:(NSRect)f
{
	if (!(self = [super initWithFrame: f])) return nil;
	screenW = [[NSScreen mainScreen] frame].size.width; screenH = [[NSScreen mainScreen] frame].size.height;
	m = (DockMetrics){ 58, 99, 1, (int)screenW };
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile: [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/com.apple.dock.plist"]];
	if ([prefs[@"tilesize"] intValue] > 0) m.tilesize = [prefs[@"tilesize"] intValue];
	if ([prefs[@"largesize"] intValue] > 0) m.largesize = [prefs[@"largesize"] intValue];
	if (prefs[@"magnification"]) m.magnification = [prefs[@"magnification"] boolValue];
	pointer = -1; hover = -1;
	wsc = ws_connect(NULL);
	[[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(miniNote:) name: @"com.wsbsd.dock.minimize" object: nil];
	[self reload];
	timer = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60 target: self selector: @selector(tick:) userInfo: nil repeats: YES];
	return self;
}
- (void)reload
{
	paths = [NSMutableArray array]; names = [NSMutableArray array]; pids = [NSMutableArray array]; labelStore = [NSMutableArray array];
	struct { const char *label, *glyph, *path; } defs[] = {
		{ "Finder", "finder", "" }, { "Launchpad", "launchpad", "" }, { "Terminal", "terminal", "/System/Applications/Utilities/Terminal.app" },
		{ "Keyboard Setup Assistant", "settings", "/System/Applications/Utilities/Keyboard Setup Assistant.app" }, { "UITest", "generic", "/Applications/UITest.app" } };
	n = 0;
	for (size_t i = 0; i < sizeof defs / sizeof defs[0] && n < MAXITEMS - 3; i++) {
		items[n].kind = DOCK_APP; tiles[n] = (DockTile){ defs[i].label, defs[i].glyph, 0, 0, 0 };
		[paths addObject: @(defs[i].path)]; [pids addObject: @0]; n++;
	}
	items[n].kind = DOCK_SEPARATOR; tiles[n] = (DockTile){ NULL, "", 0, 0, 0 }; [paths addObject: @""]; [pids addObject: @0]; n++;
	items[n].kind = DOCK_OTHER; tiles[n] = (DockTile){ "Downloads", "folder", 0, 0, 0 }; [paths addObject: [NSHomeDirectory() stringByAppendingPathComponent: @"Downloads"]]; [pids addObject: @0]; n++;
	for (int k = 0; k < nmini && n < MAXITEMS - 2; k++) {                       /* minimized windows without a tile of their application: after the Downloads stack, before the Trash */
		mini[k].item = -1; if (mini[k].appItem >= 0) continue;
		items[n].kind = DOCK_MINIMIZED; mini[k].item = n; tiles[n] = (DockTile){ mini[k].label, mini[k].phase == 2 ? "doc" : "none", 0, 0, 0, mini[k].phase == 2 ? mini[k].thumb : NULL };
		[paths addObject: @""]; [pids addObject: @0]; n++;
	}
	items[n].kind = DOCK_TRASH; tiles[n] = (DockTile){ "Trash", "trash", 0, 0, 0 }; [paths addObject: @""]; [pids addObject: @0]; n++;
	winW = 0;                                                                   /* the window geometry follows the items */
	for (int i = 0; i < n; i++) { scale[i] = 1; bounceStart[i] = 0; if (items[i].kind == DOCK_APP && [paths[i] length] && [[NSFileManager defaultManager] fileExistsAtPath: paths[i]]) { if (LSBundleIconPath(paths[i])) tiles[i].icon = LSIconCreateForPath(paths[i], 256); } }
}
- (void)computeWindow
{
	double maxW = 0, minX = 1e9;                                                   /* the widest bar over a sweep of pointer positions */
	for (int k = -1; k <= 20; k++) {
		DockBar b; DockSlot tmp[MAXITEMS]; double px = k < 0 ? -1 : (k * screenW / 20.0);
		dock_layout(&m, items, n, px, tmp, &b); if (b.bar_w > maxW) maxW = b.bar_w;
	}
	(void)minX; winW = ceil(maxW) + 8; if (winW > screenW) winW = screenW; winX = floor((screenW - winW) / 2);
}
- (void)relayout
{
	double px = pointer;
	dock_layout(&m, items, n, px, slots, &bar);
}
- (CGImageRef)thumbOfWindow:(uint32_t)wid
{
	ws_surface *s = wsc ? ws_capture(wsc, (ws_rect){ 0, 0, 0, 0 }, wid, 0) : NULL; if (!s) return NULL;
	int box = 128; CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef c = CGBitmapContextCreate(NULL, box, box, 8, box * 4, cs, kCGImageAlphaPremultipliedLast);
	CGDataProviderRef dp = CGDataProviderCreateWithData(NULL, s->px, (size_t)s->stride * s->h, NULL);
	CGImageRef src = CGImageCreate(s->w, s->h, 8, 32, s->stride, cs, kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little, dp, NULL, false, kCGRenderingIntentDefault);
	double k = fmin((box - 8.0) / s->w, (box - 8.0) / s->h), w = s->w * k, h = s->h * k;
	if (src) { CGContextSetInterpolationQuality(c, kCGInterpolationHigh); CGContextDrawImage(c, CGRectMake((box - w) / 2, (box - h) / 2, w, h), src); CGImageRelease(src); }
	CGImageRef out = CGBitmapContextCreateImage(c);
	CGDataProviderRelease(dp); CGContextRelease(c); CGColorSpaceRelease(cs); ws_surface_free(s);
	return out;
}
- (void)miniNote:(NSNotification *)note
{
	NSDictionary *u = [note userInfo]; uint32_t wid = (uint32_t)[u[@"wid"] intValue]; if (!wsc || !wid || nmini >= MAXMINI) return;
	ws_win w = { .id = wid, .px = NULL }; ws_rect r; if (ws_win_get_bounds(wsc, &w, &r)) return;
	MiniWin *mw = &mini[nmini++]; memset(mw, 0, sizeof *mw);
	mw->wid = wid; mw->pid = [u[@"pid"] intValue]; snprintf(mw->label, sizeof mw->label, "%s", [u[@"title"] length] ? [u[@"title"] UTF8String] : "Window");
	mw->thumb = [self thumbOfWindow: wid]; mw->phase = 1; mw->t0 = Now(); mw->appItem = -1;
	{                                                                           /* the application's tile: by the bundle path, or by the executable lying inside the tile's .app (the program may run through a wrapper) */
		NSString *bp = u[@"bundle"], *exe = u[@"exe"];
		for (int i = 0; i < n; i++) {
			if (items[i].kind != DOCK_APP || ![paths[i] length]) continue;
			BOOL hit = ([bp length] && ([paths[i] isEqualToString: bp] || [[paths[i] lastPathComponent] isEqualToString: [bp lastPathComponent]])) || ([exe length] && [exe hasPrefix: [paths[i] stringByAppendingString: @"/"]]);
			if (hit) { mw->appItem = i; break; }
		}
	}
	int sw = 0, sh = 0; ws_conn_screen(wsc, &sw, &sh); mw->wr[0] = r.x; mw->wr[1] = sh - (r.y + r.h); mw->wr[2] = r.w; mw->wr[3] = r.h;
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.dock.minimized" object: nil userInfo: @{ @"wid": @(wid) } deliverImmediately: YES];
	[self reload];
}
- (void)stepMini
{
	for (int k = 0; k < nmini; k++) {
		MiniWin *mw = &mini[k]; if (mw->phase == 2 || !wsc) continue;
		double p = (Now() - mw->t0) / (mw->phase == 1 ? 0.75 : 0.5); if (p > 1) p = 1; if (mw->phase == 3) p = 1 - p;
		int ti = mw->appItem >= 0 ? mw->appItem : mw->item; if (ti < 0 || ti >= n) continue;
		const DockSlot *sl = &slots[ti]; ws_win w = { .id = mw->wid, .px = NULL };
		double icon[4] = { sl->cx - sl->art / 2, bar.bottom_margin + 15, sl->art, sl->art }; int cols, rows; float done;
		int nf = genie_mesh(mw->wr, icon, (float)p, 1, genieMesh, &cols, &rows, &done);
		if (nf && !(mw->phase == 1 && p >= 1) && !(mw->phase == 3 && p <= 0)) ws_win_warp(wsc, &w, cols, rows, genieMesh);
		if (mw->phase == 1 && p >= 1) { ws_win_order(wsc, &w, WS_OUT, 0); ws_win_warp(wsc, &w, 0, 0, NULL); mw->phase = 2; }
		else if (mw->phase == 3 && p <= 0) {
			ws_win_warp(wsc, &w, 0, 0, NULL); if (mw->thumb) CGImageRelease(mw->thumb);
			memmove(&mini[k], &mini[k + 1], (size_t)(nmini - k - 1) * sizeof mini[0]); nmini--; k--; [self reload];
		}
	}
	for (int k = 0; k < nmini; k++) { int i = mini[k].item; if (i >= 0 && i < n) { tiles[i].icon = mini[k].phase == 2 ? mini[k].thumb : NULL; tiles[i].glyph = mini[k].phase == 2 ? "doc" : "none"; } }
}
- (void)restoreMini:(int)k
{
	MiniWin *mw = &mini[k]; if (mw->phase != 2 || !wsc) return;
	ws_win w = { .id = mw->wid, .px = NULL };
	int ti = mw->appItem >= 0 ? mw->appItem : mw->item; const DockSlot *sl = &slots[ti]; double icon[4] = { sl->cx - sl->art / 2, bar.bottom_margin + 15, sl->art, sl->art }; int cols, rows; float done;
	if (genie_mesh(mw->wr, icon, 1.0f, 1, genieMesh, &cols, &rows, &done)) ws_win_warp(wsc, &w, cols, rows, genieMesh);      /* collapsed into the tile before it is shown */
	ws_win_order(wsc, &w, WS_ABOVE, 0);
	mw->phase = 3; mw->t0 = Now();
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.dock.restore" object: nil userInfo: @{ @"wid": @(mw->wid) } deliverImmediately: YES];
}
- (void)tick:(NSTimer *)t
{
	for (int i = 0; i < n; i++) {
		int pid = [pids[i] intValue]; tiles[i].running = pid > 0 && kill(pid, 0) == 0;
		if (bounceStart[i] > 0) {                                                  /* the launch bounce: three arcs of decreasing height, 0.6 s each... */
			double t = Now() - bounceStart[i], dur = 2.0; if (t > dur) { bounceStart[i] = 0; tiles[i].bounce = 0; }
			else { double ph = fmod(t, 0.66) / 0.66; tiles[i].bounce = (float)(4 * ph * (1 - ph) * (1.0 - t / dur) * 0.75); }
		}
	}
	if (wsc && !fanOpen) {                                                      /* the pointer from the window server: the bar unzooms when it leaves (tracking events are not reliable) */
		int px, py; if (ws_cursor_position(wsc, &px, &py) == 0) {
			NSRect wf = [[self window] frame]; double top = screenH - wf.size.height;
			if (py >= top && px >= wf.origin.x && px < wf.origin.x + wf.size.width) { pointer = px; hover = [self tileAt: pointer]; } else { pointer = -1; hover = -1; }
		}
	}
	[self relayout];
	if (wsc && !fanOpen) {                                                      /* the glass of the bar: the window server blurs and bends what is behind the bar's rounded rectangle (the window is larger than the bar) */
		ws_win gw = { .id = (ws_wid)[[self window] windowNumber], .px = NULL }; double wh = [[self window] frame].size.height;
		ws_rect gr = { (int)floor(bar.bar_x - winX), (int)floor(wh - (bar.bottom_margin + bar.bar_h)), (int)ceil(bar.bar_w), (int)ceil(bar.bar_h) };
		if (gr.x != glassRect.x || gr.y != glassRect.y || gr.w != glassRect.w || gr.h != glassRect.h || !glassOn) { ws_win_glass(wsc, &gw, gr, 18, 1); glassRect = gr; glassOn = 1; }
	} else if (wsc && fanOpen && glassOn) { ws_win_glass(wsc, &(ws_win){ .id = (ws_wid)[[self window] windowNumber], .px = NULL }, (ws_rect){ 0, 0, 0, 0 }, 0, 0); glassOn = 0; }
	[self stepMini];
	if (getenv("DOCK_FAN") && !fanOpen && !fanStart) { [self openFan: n - 2]; }
	NSWindow *w = [self window];
	if (winW <= 0) [self computeWindow];
	NSRect f = NSMakeRect(winX, 0, winW, 170);
	if (fanOpen && fanDir && Now() - fanCheck > 0.5) {                        /* the folder changed while the fan is open: list it again (the fan keeps its opening state) */
		fanCheck = Now(); double mt = [[[[NSFileManager defaultManager] attributesOfItemAtPath: fanDir error: NULL] fileModificationDate] timeIntervalSinceReferenceDate];
		if (mt != fanMTime) { double st = fanStart; int anchor = fan.anchor; [self openFan: anchor]; fanStart = st - 1; }
	}
	if (fanOpen) {                                                             /* the fan: the window covers the screen so that a click anywhere closes it */
		double el = Now() - fanStart; fan.t = el; fan.u = 1;
		if (fanClose > 0) { double ce = Now() - fanClose; fan.u = 1 - ce / 0.15; fan.t = 1; if (fan.u <= 0) { fanOpen = 0; fanClose = 0; } }
		f = NSMakeRect(0, 0, screenW, fmin(screenH, 170 + 64 * (fan.n + 1)));
	}
	NSRect cur = [w frame];
	if (fabs(f.origin.x - cur.origin.x) >= 1 || fabs(f.size.width - cur.size.width) >= 1 || fabs(f.size.height - cur.size.height) >= 1) { [w setFrame: f display: NO]; }
	[self setNeedsDisplay: YES];
}
- (void)drawRect:(NSRect)r
{
	CGContextRef c = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	if (getenv("DOCK_LOG")) { static int k; if (k++ < 3) NSLog(@"dock: drawRect %@ port %p", NSStringFromRect(r), c); }
	if (!c) return;
	if (getenv("DOCK_TEST")) { CGContextSetRGBFillColor(c, 1, 0, 0, 1); CGContextFillRect(c, CGRectMake(10, 10, 200, 100)); NSRectFill(NSMakeRect(250, 10, 100, 100)); }
	else { CGContextSaveGState(c); CGContextClearRect(c, NSRectToCGRect([self bounds])); CGContextRestoreGState(c); }
	DockScene sc = { m, items, tiles, n, slots, bar, fanOpen ? 0 : winX, [self bounds].size.height, hover, fanOpen ? &fan : NULL };
	DockRender(c, &sc);
}
- (int)tileAt:(double)x
{
	for (int i = 0; i < n; i++) if (items[i].kind != DOCK_SEPARATOR && x >= slots[i].x && x < slots[i].x + slots[i].w) return i;
	return -1;
}
- (double)screenX:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; return p.x + (fanOpen ? 0 : winX); }
- (void)openFan:(int)i
{
	NSString *dir = paths[i]; NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *all = [fm contentsOfDirectoryAtPath: dir error: NULL];
	NSMutableArray *vis = [NSMutableArray array];
	for (NSString *nm in all) if (![nm hasPrefix: @"."]) [vis addObject: nm];
	[vis sortUsingComparator: ^NSComparisonResult(NSString *a, NSString *b) {                 /* newest first */
		NSDate *da = [[fm attributesOfItemAtPath: [dir stringByAppendingPathComponent: a] error: NULL] fileModificationDate], *db = [[fm attributesOfItemAtPath: [dir stringByAppendingPathComponent: b] error: NULL] fileModificationDate];
		return [db compare: da ?: [NSDate distantPast]]; }];
	fanStore = [NSMutableArray array]; for (int k = 0; k < fan.n; k++) { free((void *)fan.labels[k]); if (fan.icons[k]) CGImageRelease(fan.icons[k]); } memset(&fan, 0, sizeof fan);
	int maxShown = (int)((screenH - 40 /*menu bar*/ - 110 - 64) / 64); if (maxShown > 14) maxShown = 14; if (maxShown < 3) maxShown = 3; int cnt = (int)[vis count]; if (cnt == 0) { [vis addObject: @"Empty"]; cnt = 1; }
	int shown = cnt > maxShown + 1 ? maxShown : cnt;
	for (int k = 0; k < shown; k++) {
		BOOL isdir = NO; [fm fileExistsAtPath: [dir stringByAppendingPathComponent: vis[k]] isDirectory: &isdir];
		[fanStore addObject: vis[k]]; fan.icons[fan.n] = LSIconCreateForPath([dir stringByAppendingPathComponent: vis[k]], 128); fan.labels[fan.n] = strdup([vis[k] UTF8String]); fan.glyphs[fan.n] = isdir ? "folder" : "doc"; fan.n++;
	}
	if (cnt > shown) { NSString *more = [NSString stringWithFormat: @"%d More in Finder", cnt - shown]; [fanStore addObject: more]; fan.labels[fan.n] = strdup([more UTF8String]); fan.glyphs[fan.n] = "folder"; fan.n++; }
	fan.anchor = i; fanOpen = 1; fanStart = Now(); fanClose = 0;
	fanDir = dir; fanMTime = [[[fm attributesOfItemAtPath: dir error: NULL] fileModificationDate] timeIntervalSinceReferenceDate];
}
- (void)mouseMoved:(NSEvent *)e { pointer = [self screenX: e]; hover = [self tileAt: pointer]; }
- (void)mouseExited:(NSEvent *)e { pointer = -1; hover = -1; }
- (void)mouseEntered:(NSEvent *)e { pointer = [self screenX: e]; }
- (void)mouseDown:(NSEvent *)e
{
	int i = [self tileAt: [self screenX: e]];
	if (fanOpen) { if (!fanClose) fanClose = Now(); return; }
	if (i < 0 || !tiles[i].label) return;
	NSString *path = paths[i];
	if (items[i].kind == DOCK_APP) { for (int k = nmini - 1; k >= 0; k--) if (mini[k].appItem == i && mini[k].phase == 2) { [self restoreMini: k]; return; } }
	if (items[i].kind == DOCK_MINIMIZED) { for (int k = 0; k < nmini; k++) if (mini[k].item == i) [self restoreMini: k]; return; }
	if (items[i].kind == DOCK_OTHER) { [self openFan: i]; return; }
	if (items[i].kind == DOCK_APP && path.length && [[NSFileManager defaultManager] fileExistsAtPath: path]) {
		bounceStart[i] = Now();
		NSString *exe = [[path stringByAppendingPathComponent: @"Contents/MacOS"] stringByAppendingPathComponent: [[path lastPathComponent] stringByDeletingPathExtension]];
		NSTask *task = [[NSTask alloc] init]; [task setLaunchPath: exe]; @try { [task launch]; pids[i] = @([task processIdentifier]); } @catch (NSException *x) {}
	}
}
- (void)viewDidMoveToWindow { [[self window] setAcceptsMouseMovedEvents: YES]; [[self window] makeFirstResponder: self]; [self resetTracking]; }
- (void)setFrameSize:(NSSize)sz { [super setFrameSize: sz]; [self resetTracking]; }
- (void)resetTracking { if (trackTag) [self removeTrackingRect: trackTag]; trackTag = [self addTrackingRect: [self bounds] owner: self userData: nil assumeInside: NO]; }
@end

int main(int argc, char *argv[])
{
	@autoreleasepool {
		NSApplication *app = [NSApplication sharedApplication];
		DockView *v = [[DockView alloc] initWithFrame: NSMakeRect(0, 0, 1200, 170)];
		[v relayout];
		if (getenv("DOCK_LOG")) NSLog(@"dock: screen %.0f bar %.1f %.1f items %d tilesize %d", v->screenW, v->bar.bar_x, v->bar.bar_w, v->n, v->m.tilesize);
		[v computeWindow]; NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(v->winX, 0, v->winW, 170) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		if (getenv("DOCK_TEST")) { [w setBackgroundColor: [NSColor greenColor]]; } else { [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; } [w setHasShadow: NO]; [w setLevel: getenv("DOCK_LEVEL") ? atoi(getenv("DOCK_LEVEL")) : 20]; [w setHidesOnDeactivate: NO]; [w setCanHide: NO]; [w setContentView: v]; [w setAcceptsMouseMovedEvents: YES];
		[w orderFrontRegardless];
		[app run];
	}
	return 0;
}
