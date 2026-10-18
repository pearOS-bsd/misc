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
typedef struct { uint32_t wid; int pid; char label[64]; char bpath[512]; CGImageRef thumb; int phase; double t0; double wr[4]; int item; int appItem; } MiniWin;       /* phase: 1 minimizing, 2 settled, 3 restoring */
#define MAXMINI 16

@interface DockView : NSView {
@public
	ws_rect glassRect; int glassOn;
	NSString *fanDir; double fanMTime, fanCheck;      /* the folder of the open fan and its modification time: the fan lists it again when it changes */
	double winX, winW;     /* the bar's window: as wide as the bar gets when magnified, fixed for the current items (resizing the window every frame made the Dock flicker) */
	MiniWin mini[MAXMINI]; int nmini; ws_conn *wsc; float genieMesh[GENIE_MAX_FLOATS];
	DockMetrics m; DockItem items[MAXITEMS]; DockTile tiles[MAXITEMS]; DockSlot slots[MAXITEMS]; DockBar bar; int n;
	NSMutableArray *paths; NSMutableArray *names; NSMutableArray *pids; NSMutableArray *labelStore;
	NSMutableDictionary *prefs; NSMutableArray *apps, *others; int srcKind[MAXITEMS], srcIdx[MAXITEMS];      /* srcKind: 0 pinned application, 1 running application without a tile, 2 right-hand section, -1 other */
	NSMutableDictionary *iconCache; NSSet *runningPaths; NSDictionary *runningPids; double scanT; NSString *scanKey;
	int autohide; double hideDelay, hideTime, hideFrac, hideT0, reveal0, dwell0; int hidden;                  /* hideFrac: 0 shown ... 1 hidden */
	NSArray *ctxItems; int ctxOpen, ctxSub, ctxHoverMain, ctxHoverSub; NSRect ctxMainR, ctxSubR; NSArray *ctxSubItems; double ctxH;
	int ctxItem, dragCand, dragItem, dragging; double dragStartX; int trashFull;
	NSTrackingRectTag trackTag; double pointer; int hover; double scale[MAXITEMS]; double bounceStart[MAXITEMS]; NSTimer *timer; double screenW, screenH, screenLen, alongBase; int orient; DockFan fan; int fanOpen; double fanStart, fanClose; NSMutableArray *fanStore;
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
	iconCache = [NSMutableDictionary dictionary];
	[self loadPrefs];
	pointer = -1; hover = -1;
	wsc = ws_connect(NULL);
	[[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(miniNote:) name: @"com.wsbsd.dock.minimize" object: nil];
	[self reload];
	timer = [NSTimer scheduledTimerWithTimeInterval: 1.0 / 60 target: self selector: @selector(tick:) userInfo: nil repeats: YES];
	return self;
}
- (NSString *)prefsPath { return [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/com.apple.dock.plist"]; }
/* a tile of the plist: the path of its file and its label */
static NSString *TilePath(NSDictionary *t)
{
	NSDictionary *td = t[@"tile-data"]; NSDictionary *fd = td[@"file-data"]; NSString *u = fd[@"_CFURLString"]; if (![u length]) return @"";
	NSURL *url = [NSURL URLWithString: u]; NSString *p = [url isFileURL] ? [url path] : [u stringByRemovingPercentEncoding];
	while ([p length] > 1 && [p hasSuffix: @"/"]) p = [p substringToIndex: [p length] - 1];
	return p ?: @"";
}
static NSString *TileLabel(NSDictionary *t, NSString *path)
{
	NSString *l = t[@"tile-data"][@"file-label"]; return [l length] ? l : [[path lastPathComponent] stringByDeletingPathExtension];
}
- (void)loadPrefs
{
	prefs = [NSMutableDictionary dictionaryWithContentsOfFile: [self prefsPath]] ?: [NSMutableDictionary dictionary];
	NSString *ori = prefs[@"orientation"]; orient = [ori isEqualToString: @"left"] ? 1 : [ori isEqualToString: @"right"] ? 2 : 0;
	alongBase = orient ? 30 : 0; screenLen = orient ? screenH - alongBase : screenW;                           /* a bar on a side is centred below the menu bar */
	m = (DockMetrics){ 58, 99, 1, (int)screenLen };
	if ([prefs[@"tilesize"] intValue] > 0) m.tilesize = [prefs[@"tilesize"] intValue];
	if ([prefs[@"largesize"] intValue] > 0) m.largesize = [prefs[@"largesize"] intValue];
	if (prefs[@"magnification"]) m.magnification = [prefs[@"magnification"] boolValue];
	autohide = [prefs[@"autohide"] boolValue]; hideDelay = prefs[@"autohide-delay"] ? [prefs[@"autohide-delay"] doubleValue] : 0.5;
	hideTime = prefs[@"autohide-time-modifier"] ? [prefs[@"autohide-time-modifier"] doubleValue] : 0.5;
	apps = [NSMutableArray array]; others = [NSMutableArray array];
	for (NSDictionary *t in prefs[@"persistent-apps"]) [apps addObject: [t mutableCopy]];
	for (NSDictionary *t in prefs[@"persistent-others"]) [others addObject: [t mutableCopy]];
	if (![apps count] && !prefs[@"persistent-apps"]) {                          /* no preferences: the default set of this system */
		struct { const char *label, *path; } defs[] = { { "Terminal", "/System/Applications/Utilities/Terminal.app" },
			{ "Keyboard Setup Assistant", "/System/Applications/Utilities/Keyboard Setup Assistant.app" }, { "UITest", "/Applications/UITest.app" } };
		for (size_t i = 0; i < sizeof defs / sizeof defs[0]; i++) [apps addObject: [self tileForPath: @(defs[i].path) label: @(defs[i].label)]];
		[others addObject: [@{ @"tile-type": @"directory-tile", @"tile-data": @{ @"file-data": @{ @"_CFURLString": [@"file://" stringByAppendingString: [[NSHomeDirectory() stringByAppendingPathComponent: @"Downloads"] stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLPathAllowedCharacterSet]]], @"_CFURLStringType": @0 }, @"file-label": @"Downloads", @"arrangement": @2, @"showas": @1, @"displayas": @0 } } mutableCopy]];
	}
}
- (NSMutableDictionary *)tileForPath:(NSString *)path label:(NSString *)label
{
	NSString *u = [@"file://" stringByAppendingString: [path stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLPathAllowedCharacterSet]]];
	return [@{ @"GUID": @(arc4random()), @"tile-type": @"file-tile", @"tile-data": @{ @"file-data": @{ @"_CFURLString": [u stringByAppendingString: @"/"], @"_CFURLStringType": @15 }, @"file-label": label ?: [[path lastPathComponent] stringByDeletingPathExtension], @"file-type": @41, @"dock-extra": @NO } } mutableCopy];
}
- (void)savePrefs
{
	prefs[@"persistent-apps"] = apps; prefs[@"persistent-others"] = others;
	NSString *dir = [[self prefsPath] stringByDeletingLastPathComponent]; [[NSFileManager defaultManager] createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL];
	[prefs writeToFile: [self prefsPath] atomically: YES];
}
/* the running applications: executables inside a .app bundle in the process list */
- (void)scanProcesses
{
	NSMutableDictionary *pm = [NSMutableDictionary dictionary];
	FILE *f = popen("ps -axo pid=,command= 2>/dev/null", "r");
	if (f) {
		char line[2048];
		while (fgets(line, sizeof line, f)) {
			char *mark = strstr(line, ".app/Contents/MacOS/"); if (!mark) continue;
			int pid = atoi(line); *mark = 0; char *start = line; while (*start == ' ') start++; while (*start >= '0' && *start <= '9') start++; while (*start == ' ') start++;
			NSString *bp = [[NSString stringWithUTF8String: start] stringByAppendingString: @".app"]; if (!pm[bp]) pm[bp] = @(pid);
		}
		pclose(f);
	}
	runningPids = pm; runningPaths = [NSSet setWithArray: [pm allKeys]];
}
- (BOOL)isSystemApp:(NSString *)bp
{
	NSString *n = [bp lastPathComponent];
	return [bp rangeOfString: @"/CoreServices/"].length || [n isEqualToString: @"Dock.app"] || [n isEqualToString: @"TopBar.app"] || [n isEqualToString: @"Top Bar.app"];
}
- (CGImageRef)iconForPath:(NSString *)path
{
	if (![path length] || !LSBundleIconPath(path)) return NULL;
	if (!iconCache[path]) { CGImageRef i = LSIconCreateForPath(path, 256); iconCache[path] = i ? (id)CFBridgingRelease(i) : (id)[NSNull null]; }
	id v = iconCache[path]; return v == [NSNull null] ? NULL : (__bridge CGImageRef)v;
}
/* the labels are kept in C strings: the NSStrings' own buffers do not live long enough */
static char *labelBuf[MAXITEMS + 8];
static const char *Keep(int slot, const char *s) { free(labelBuf[slot]); labelBuf[slot] = strdup(s); return labelBuf[slot]; }
- (void)reload
{
	paths = [NSMutableArray array]; names = [NSMutableArray array]; pids = [NSMutableArray array]; labelStore = [NSMutableArray array];
	NSFileManager *fm = [NSFileManager defaultManager]; n = 0; memset(tiles, 0, sizeof tiles);
#define PUSH(K, LBL, GLYPH, PATH, SK, SI) do { items[n].kind = (K); tiles[n] = (DockTile){ (LBL) ? Keep(n, (LBL)) : NULL, (GLYPH), 0, 0, 0 }; [paths addObject: (PATH)]; [pids addObject: @0]; srcKind[n] = (SK); srcIdx[n] = (SI); n++; } while (0)
	NSMutableSet *pinned = [NSMutableSet set];
	for (NSUInteger k = 0; k < [apps count] && n < MAXITEMS - 4; k++) {
		NSDictionary *t = apps[k]; NSString *tt = t[@"tile-type"];
		if ([tt isEqualToString: @"spacer-tile"]) { PUSH(DOCK_SPACER, NULL, "", @"", 0, (int)k); continue; }
		if ([tt isEqualToString: @"small-spacer-tile"]) { PUSH(DOCK_SMALLSPACER, NULL, "", @"", 0, (int)k); continue; }
		NSString *path = TilePath(t); if (![path length] || ![fm fileExistsAtPath: path]) continue;        /* an application that is not installed has no tile here */
		[pinned addObject: path]; [labelStore addObject: TileLabel(t, path)];
		PUSH(DOCK_APP, [[labelStore lastObject] UTF8String], "generic", path, 0, (int)k);
	}
	if ([prefs[@"static-only"] boolValue] == NO) {                              /* running applications that are not in the Dock: after a separator */
		NSMutableArray *extra = [NSMutableArray array]; for (NSString *bp in [[runningPaths allObjects] sortedArrayUsingSelector: @selector(compare:)]) if (![pinned containsObject: bp] && ![self isSystemApp: bp]) [extra addObject: bp];
		if ([extra count]) PUSH(DOCK_SEPARATOR, NULL, "", @"", -1, 0);
		for (NSString *bp in extra) { if (n >= MAXITEMS - 4) break; [labelStore addObject: [[bp lastPathComponent] stringByDeletingPathExtension]]; PUSH(DOCK_APP, [[labelStore lastObject] UTF8String], "generic", bp, 1, 0); }
	}
	PUSH(DOCK_SEPARATOR, NULL, "", @"", -1, 0);
	for (NSUInteger k = 0; k < [others count] && n < MAXITEMS - 3; k++) {
		NSDictionary *t = others[k]; NSString *path = TilePath(t); if (![path length] || ![fm fileExistsAtPath: path]) continue;
		[labelStore addObject: TileLabel(t, path)]; BOOL dir = [t[@"tile-type"] isEqualToString: @"directory-tile"];
		PUSH(dir ? DOCK_OTHER : DOCK_OTHER, [[labelStore lastObject] UTF8String], dir ? "folder" : "doc", path, 2, (int)k);
	}
	for (int k = 0; k < nmini; k++) {                                           /* the tile of a minimized window's application may have moved */
		if (!mini[k].bpath[0]) continue; mini[k].appItem = -1; NSString *bp = @(mini[k].bpath);
		for (int i = 0; i < n; i++) if (items[i].kind == DOCK_APP && [paths[i] isEqualToString: bp]) { mini[k].appItem = i; break; }
	}
	for (int k = 0; k < nmini && n < MAXITEMS - 2; k++) {                       /* minimized windows without a tile of their application: after the Downloads stack, before the Trash */
		mini[k].item = -1; if (mini[k].appItem >= 0) continue;
		items[n].kind = DOCK_MINIMIZED; mini[k].item = n; tiles[n] = (DockTile){ mini[k].label, mini[k].phase == 2 ? "doc" : "none", 0, 0, 0, mini[k].phase == 2 ? mini[k].thumb : NULL };
		[paths addObject: @""]; [pids addObject: @0]; srcKind[n] = -1; n++;
	}
	PUSH(DOCK_TRASH, "Trash", "trash", @"", -1, 0);
	winW = 0;                                                                   /* the window geometry follows the items */
	for (int i = 0; i < n; i++) { scale[i] = 1; bounceStart[i] = 0; if (items[i].kind == DOCK_APP) { CGImageRef ic = [self iconForPath: paths[i]]; if (ic) tiles[i].icon = ic; } }
	scanKey = [[[runningPaths allObjects] sortedArrayUsingSelector: @selector(compare:)] componentsJoinedByString: @"|"];
}
- (BOOL)wide { return fanOpen || ctxOpen; }
- (double)originX { return [self wide] ? (orient ? -alongBase : 0) : winX; }          /* the along-coordinate of the window's start */
/* the window's frame for the state: the bar's own window, or the whole screen while a fan or a menu is open */
- (NSRect)stateFrame
{
	double thick = (autohide && hideFrac >= 1) ? 2 : orient ? 320 : 170;
	if (!orient) {
		if (fanOpen) return NSMakeRect(0, 0, screenW, fmin(screenH, 170 + 64 * (fan.n + 1)));
		if (ctxOpen) return NSMakeRect(0, 0, screenW, fmin(screenH, 170 + ctxH));
		return NSMakeRect(winX, 0, winW, thick);
	}
	if ([self wide]) return NSMakeRect(0, 0, screenW, screenH);
	return NSMakeRect(orient == 1 ? 0 : screenW - thick, screenH - (alongBase + winX + winW), thick, winW);
}
- (void)iconRect:(int)i into:(double *)r                                            /* the tile's rectangle for the genie, x from the left, y up */
{
	const DockSlot *sl = &slots[i];
	if (!orient) { r[0] = sl->cx - sl->art / 2; r[1] = bar.bottom_margin + 15; }
	else { r[0] = orient == 1 ? bar.bottom_margin + 15 : screenW - (bar.bottom_margin + 15) - sl->art; r[1] = screenH - (alongBase + sl->cx) - sl->art / 2; }
	r[2] = r[3] = sl->art;
}
- (void)computeWindow
{
	double maxW = 0, minX = 1e9;                                                   /* the widest bar over a sweep of pointer positions */
	for (int k = -1; k <= 20; k++) {
		DockBar b; DockSlot tmp[MAXITEMS]; double px = k < 0 ? -1 : (k * screenLen / 20.0);
		dock_layout(&m, items, n, px, tmp, &b); if (b.bar_w > maxW) maxW = b.bar_w;
	}
	(void)minX; winW = ceil(maxW) + 8; if (winW > screenLen) winW = screenLen; winX = floor((screenLen - winW) / 2);
}
- (void)relayout
{
	double px = pointer;
	dock_layout(&m, items, n, px, slots, &bar);
	double e = hideFrac * hideFrac * (3 - 2 * hideFrac); bar.bottom_margin = 5 - e * (bar.bar_h + 12);        /* autohide: the bar slides below the screen's edge */
}
- (void)stepAutohide
{
	static double last; double dt = last ? Now() - last : 0.016; last = Now(); if (dt > 0.1) dt = 0.1;
	if (!autohide) { hideFrac = 0; return; }
	int px = 0, py = 0; if (!wsc || ws_cursor_position(wsc, &px, &py)) return;
	double zone = 5 + bar.bar_h + 14 + (m.magnification ? m.largesize - m.tilesize : 0);
	BOOL atEdge = orient == 1 ? px <= 0 : orient == 2 ? px >= screenW - 1 : py >= screenH - 1, inZone = orient == 1 ? px <= zone : orient == 2 ? px >= screenW - zone : py >= screenH - zone, keep = fanOpen || ctxOpen || dragging || (hideFrac < 1 && inZone);
	if (hideFrac >= 1) { if (atEdge) { if (!dwell0) dwell0 = Now(); if (Now() - dwell0 >= hideDelay) { keep = YES; dwell0 = 0; } } else dwell0 = 0; }
	double step = dt / fmax(hideTime, 0.05);
	if (keep) hideFrac = fmax(0, hideFrac - step); else hideFrac = fmin(1, hideFrac + step);
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
			if (hit) { mw->appItem = i; snprintf(mw->bpath, sizeof mw->bpath, "%s", [paths[i] UTF8String]); break; }
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
		double icon[4]; [self iconRect: ti into: icon]; int cols, rows; float done;
		int nf = genie_mesh(mw->wr, icon, (float)p, orient ? 2 + orient : 1, genieMesh, &cols, &rows, &done);
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
	int ti = mw->appItem >= 0 ? mw->appItem : mw->item; const DockSlot *sl = &slots[ti]; double icon[4]; [self iconRect: ti into: icon]; int cols, rows; float done;
	if (genie_mesh(mw->wr, icon, 1.0f, orient ? 2 + orient : 1, genieMesh, &cols, &rows, &done)) ws_win_warp(wsc, &w, cols, rows, genieMesh);      /* collapsed into the tile before it is shown */
	ws_win_order(wsc, &w, WS_ABOVE, 0);
	mw->phase = 3; mw->t0 = Now();
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.dock.restore" object: nil userInfo: @{ @"wid": @(mw->wid) } deliverImmediately: YES];
}
- (void)tick:(NSTimer *)t
{
	if (Now() - scanT > 1.5) {                                                  /* the running applications: a tile appears for one that is not in the Dock, and goes when it quits */
		scanT = Now(); [self scanProcesses];
		NSString *key = [[[runningPaths allObjects] sortedArrayUsingSelector: @selector(compare:)] componentsJoinedByString: @"|"];
		BOOL full = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath: [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"] error: NULL] count] > 0;
		if (![key isEqualToString: scanKey] && !dragging) [self reload];
		trashFull = full;
	}
	[self stepAutohide];
	for (int i = 0; i < n; i++) {
		int pid = [pids[i] intValue]; tiles[i].running = (pid > 0 && kill(pid, 0) == 0) || (items[i].kind == DOCK_APP && [runningPaths containsObject: paths[i]]);
		if (bounceStart[i] > 0) {                                                  /* the launch bounce: three arcs of decreasing height, 0.6 s each... */
			double t = Now() - bounceStart[i], dur = 2.0; if (t > dur) { bounceStart[i] = 0; tiles[i].bounce = 0; }
			else { double ph = fmod(t, 0.66) / 0.66; tiles[i].bounce = (float)(4 * ph * (1 - ph) * (1.0 - t / dur) * 0.75); }
		}
	}
	if (ctxOpen && wsc) { int px, py; if (ws_cursor_position(wsc, &px, &py) == 0) [self ctxHoverAt: NSMakePoint(px, screenH - py)]; pointer = -1; hover = -1; }
	if (wsc && !fanOpen && !ctxOpen) {                                          /* the pointer from the window server: the bar unzooms when it leaves (tracking events are not reliable) */
		int px, py; if (ws_cursor_position(wsc, &px, &py) == 0) {
			NSRect wf = [[self window] frame]; double top = screenH - (wf.origin.y + wf.size.height);
			if (hideFrac < 1 && py >= top && py < top + wf.size.height && px >= wf.origin.x && px < wf.origin.x + wf.size.width) { pointer = orient ? py - alongBase : px; hover = [self tileAt: pointer]; } else { pointer = -1; hover = -1; }
		}
	}
	[self relayout];
	if (wsc && !fanOpen && !(autohide && hideFrac >= 1)) { double ox = ctxOpen ? 0 : winX; (void)ox;                      /* the glass of the bar: the window server blurs and bends what is behind the bar's rounded rectangle (the window is larger than the bar) */
		ws_win gw = { .id = (ws_wid)[[self window] windowNumber], .px = NULL }; double wh = [[self window] frame].size.height;
		ws_rect gr = { (int)floor(bar.bar_x - ox), (int)floor(wh - (bar.bottom_margin + bar.bar_h)), (int)ceil(bar.bar_w), (int)ceil(bar.bar_h) };
		if (orient) { double ww = [[self window] frame].size.width; gr = (ws_rect){ (int)floor(orient == 1 ? bar.bottom_margin : ww - (bar.bottom_margin + bar.bar_h)), (int)floor(bar.bar_x - [self originX]), (int)ceil(bar.bar_h), (int)ceil(bar.bar_w) }; }
		if (gr.x != glassRect.x || gr.y != glassRect.y || gr.w != glassRect.w || gr.h != glassRect.h || !glassOn) { ws_win_glass(wsc, &gw, gr, 18, 1); glassRect = gr; glassOn = 1; }
	} else if (wsc && glassOn) { ws_win_glass(wsc, &(ws_win){ .id = (ws_wid)[[self window] windowNumber], .px = NULL }, (ws_rect){ 0, 0, 0, 0 }, 0, 0); glassOn = 0; }
	[self stepMini];
	if (getenv("DOCK_FAN") && !fanOpen && !fanStart) { [self openFan: n - 2]; }
	NSWindow *w = [self window];
	if (winW <= 0) [self computeWindow];
	NSRect f = [self stateFrame];
	if (fanOpen && fanDir && Now() - fanCheck > 0.5) {                        /* the folder changed while the fan is open: list it again (the fan keeps its opening state) */
		fanCheck = Now(); double mt = [[[[NSFileManager defaultManager] attributesOfItemAtPath: fanDir error: NULL] fileModificationDate] timeIntervalSinceReferenceDate];
		if (mt != fanMTime) { double st = fanStart; int anchor = fan.anchor; [self openFan: anchor]; fanStart = st - 1; }
	}
	if (fanOpen) {                                                             /* the fan: the window covers the screen so that a click anywhere closes it */
		double el = Now() - fanStart; fan.t = el; fan.u = 1;
		if (fanClose > 0) { double ce = Now() - fanClose; fan.u = 1 - ce / 0.15; fan.t = 1; if (fan.u <= 0) { fanOpen = 0; fanClose = 0; } }
		f = [self stateFrame];
	}
	else if (ctxOpen) f = [self stateFrame];
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
	DockScene sc = { m, items, tiles, n, slots, bar, [self originX], [self bounds].size.height, hover, fanOpen ? &fan : NULL, orient, [self bounds].size.width };
	DockRender(c, &sc);
	if (ctxOpen) [self drawContext];
}
- (int)tileAt:(double)x
{
	for (int i = 0; i < n; i++) if (!DOCK_IS_GAP(items[i].kind) && x >= slots[i].x && x < slots[i].x + slots[i].w) return i;
	return -1;
}
- (double)screenX:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; return (orient ? [self bounds].size.height - p.y : p.x) + [self originX]; }
- (void)openFan:(int)i
{
	NSString *dir = paths[i]; NSFileManager *fm = [NSFileManager defaultManager];
	NSArray *all = [fm contentsOfDirectoryAtPath: dir error: NULL];
	NSMutableArray *vis = [NSMutableArray array];
	for (NSString *nm in all) if (![nm hasPrefix: @"."]) [vis addObject: nm];
	int arrange = 2; if (srcKind[i] == 2) arrange = [others[srcIdx[i]][@"tile-data"][@"arrangement"] intValue];
	[vis sortUsingComparator: ^NSComparisonResult(NSString *a, NSString *b) {                 /* 1 name, 2 date added, 3 date modified, 4 date created, 5 kind; the dates newest first */
		if (arrange == 1) return [a localizedCaseInsensitiveCompare: b];
		if (arrange == 5) { NSComparisonResult r = [[a pathExtension] caseInsensitiveCompare: [b pathExtension]]; return r ?: [a localizedCaseInsensitiveCompare: b]; }
		NSString *key = arrange == 4 ? NSFileCreationDate : NSFileModificationDate;
		NSDate *da = [fm attributesOfItemAtPath: [dir stringByAppendingPathComponent: a] error: NULL][key], *db = [fm attributesOfItemAtPath: [dir stringByAppendingPathComponent: b] error: NULL][key];
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
- (void)mouseMoved:(NSEvent *)e { if (ctxOpen) { [self ctxHoverAt: [self convertPoint: [e locationInWindow] fromView: nil]]; return; } pointer = [self screenX: e]; hover = [self tileAt: pointer]; }
- (void)mouseExited:(NSEvent *)e { pointer = -1; hover = -1; }
- (void)mouseEntered:(NSEvent *)e { pointer = [self screenX: e]; }
- (void)launchItem:(int)i
{
	NSString *path = paths[i];
	if (!(items[i].kind == DOCK_APP && path.length && [[NSFileManager defaultManager] fileExistsAtPath: path])) return;
	bounceStart[i] = Now();
	NSString *exe = [[path stringByAppendingPathComponent: @"Contents/MacOS"] stringByAppendingPathComponent: [[path lastPathComponent] stringByDeletingPathExtension]];
	NSTask *task = [[NSTask alloc] init]; [task setLaunchPath: exe]; @try { [task launch]; pids[i] = @([task processIdentifier]); } @catch (NSException *x) {}
}
- (void)mouseDown:(NSEvent *)e
{
	if (ctxOpen) { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; [self ctxClick: p]; return; }
	int i = [self tileAt: [self screenX: e]];
	if (fanOpen) { if (!fanClose) fanClose = Now(); return; }
	if (i < 0 || !tiles[i].label) return;
	if ([e modifierFlags] & NSControlKeyMask) { [self rightMouseDown: e]; return; }
	dragCand = i; dragStartX = [self screenX: e]; dragging = 0; dragItem = -1;
}
- (void)mouseDragged:(NSEvent *)e
{
	if (dragCand < 0 || fanOpen || ctxOpen) return;
	double x = [self screenX: e];
	if (!dragging && fabs(x - dragStartX) < 6 && !(wsc && [self pointerAbove] > 30)) return;
	if (!dragging) {
		int k = srcKind[dragCand]; if (k != 0 && k != 2 && k != 1) { dragCand = -1; return; }       /* only the tiles of the Dock move */
		dragging = 1; dragItem = dragCand; hover = -1;
	}
	pointer = -1; hover = -1;
	int t = [self tileAt: x]; int di = dragItem;
	if (t >= 0 && t != di && srcKind[t] == srcKind[di] && srcKind[di] != 1) {                 /* the tile follows the pointer through the row: the others make room */
		NSMutableArray *arr = srcKind[di] == 0 ? apps : others; int from = srcIdx[di], to = srcIdx[t];
		id o = arr[from]; [arr removeObjectAtIndex: from]; [arr insertObject: o atIndex: to];
		[self reload]; for (int q = 0; q < n; q++) if (srcKind[q] == srcKind[di] && srcIdx[q] == to) { dragItem = q; dragCand = q; break; }
	}
	if (dragItem >= 0 && dragItem < n) tiles[dragItem].bounce = [self pointerAbove] > 30 ? 0.9f : 0.25f;
}
- (double)pointerAbove                                                       /* how far the pointer is above the bar's top, in points */
{
	int px, py; if (!wsc || ws_cursor_position(wsc, &px, &py)) return 0;
	if (orient == 1) return px - (5 + bar.bar_h); if (orient == 2) return (screenW - px) - (5 + bar.bar_h);
	return (screenH - (5 + bar.bar_h)) - py;
}
- (void)mouseUp:(NSEvent *)e
{
	int i = dragCand; dragCand = -1; if (ctxOpen) return;
	if (dragging) {
		dragging = 0; int d = dragItem; dragItem = -1;
		if (d >= 0 && d < n && [self pointerAbove] > 40 && srcKind[d] != -1) { [self keepToggle: d remove: YES]; }       /* dragged out of the Dock: it is removed */
		else { [self savePrefs]; [self reload]; }
		return;
	}
	if (fanOpen || i < 0 || i >= n || !tiles[i].label) return;
	NSString *path = paths[i];
	if (items[i].kind == DOCK_APP) { for (int k = nmini - 1; k >= 0; k--) if (mini[k].appItem == i && mini[k].phase == 2) { [self restoreMini: k]; return; } }
	if (items[i].kind == DOCK_MINIMIZED) { for (int k = 0; k < nmini; k++) if (mini[k].item == i) [self restoreMini: k]; return; }
	if (items[i].kind == DOCK_OTHER) { if ([self isDirTile: i]) [self openFan: i]; else [self openPath: path]; return; }
	if (items[i].kind == DOCK_TRASH) { return; }
	[self launchItem: i];
}
- (BOOL)isDirTile:(int)i { BOOL d = NO; [[NSFileManager defaultManager] fileExistsAtPath: paths[i] isDirectory: &d]; return d; }
- (void)openPath:(NSString *)p { NSTask *t = [[NSTask alloc] init]; [t setLaunchPath: @"/usr/bin/env"]; [t setArguments: @[@"xdg-open", p]]; @try { [t launch]; } @catch (NSException *x) {} }
/* "Keep in Dock" / "Remove from Dock" */
- (void)keepToggle:(int)i remove:(BOOL)rm
{
	if (srcKind[i] == 0 || srcKind[i] == 2) { NSMutableArray *arr = srcKind[i] == 0 ? apps : others; [arr removeObjectAtIndex: srcIdx[i]]; }
	else if (srcKind[i] == 1 && !rm) { NSString *p = paths[i]; [apps addObject: [self tileForPath: p label: @(tiles[i].label)]]; }
	[self savePrefs]; [self reload];
}
- (void)ctx:(NSMenuItem *)mi
{
	int code = (int)[mi tag], i = ctxItem; if (i < 0 || i >= n) return;
	switch (code) {
	case 1: [self launchItem: i]; break;                                                                       /* Open */
	case 2: { NSNumber *pid = runningPids[paths[i]]; if (pid) kill([pid intValue], SIGTERM); } break;           /* Quit */
	case 3: [self keepToggle: i remove: NO]; break;                                                            /* Keep in Dock */
	case 4: [self keepToggle: i remove: YES]; break;                                                           /* Remove from Dock */
	case 7: [self openPath: [paths[i] stringByDeletingLastPathComponent]]; break;                              /* Show in Finder */
	case 5: if (srcKind[i] == 2) [self openPath: paths[i]]; break;                                             /* Open (a file or a folder) */
	case 6: { NSString *tr = [NSHomeDirectory() stringByAppendingPathComponent: @".Trash"]; NSFileManager *fm = [NSFileManager defaultManager];       /* Empty Trash */
		for (NSString *f in [fm contentsOfDirectoryAtPath: tr error: NULL]) [fm removeItemAtPath: [tr stringByAppendingPathComponent: f] error: NULL]; trashFull = 0; } break;
	default:
		if (code >= 100 && code < 200 && srcKind[i] == 2) { others[srcIdx[i]][@"tile-data"] = [self tileData: others[srcIdx[i]] with: @"arrangement" value: @(code - 100)]; [self savePrefs]; if (fanOpen) [self openFan: fan.anchor]; }       /* Sort By */
		else if (code >= 200 && code < 210 && srcKind[i] == 2) { others[srcIdx[i]][@"tile-data"] = [self tileData: others[srcIdx[i]] with: @"displayas" value: @(code - 200)]; [self savePrefs]; }       /* Display As */
		else if (code >= 300 && code < 310 && srcKind[i] == 2) { others[srcIdx[i]][@"tile-data"] = [self tileData: others[srcIdx[i]] with: @"showas" value: @(code - 300)]; [self savePrefs]; }         /* View Content As */
	}
}
- (NSDictionary *)tileData:(NSDictionary *)t with:(NSString *)k value:(id)v { NSMutableDictionary *d = [t[@"tile-data"] mutableCopy]; d[k] = v; return d; }
- (NSMenuItem *)mitem:(NSString *)title code:(int)code state:(BOOL)on
{
	NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle: title action: @selector(ctx:) keyEquivalent: @""]; [mi setTarget: self]; [mi setTag: code]; [mi setState: on ? NSOnState : NSOffState]; return mi;
}
- (NSMenuItem *)sub:(NSString *)title items:(NSArray *)its
{
	NSMenuItem *mi = [[NSMenuItem alloc] initWithTitle: title action: NULL keyEquivalent: @""]; NSMenu *sm = [[NSMenu alloc] initWithTitle: title];
	for (NSMenuItem *x in its) [sm addItem: x]; [mi setSubmenu: sm]; return mi;
}
static NSDictionary *E(NSString *t, int code, BOOL on, BOOL dis) { return @{ @"t": t, @"c": @(code), @"on": @(on), @"dis": @(dis) }; }
static NSDictionary *ESep(void) { return @{ @"sep": @YES }; }
static NSDictionary *ESub(NSString *t, NSArray *sub) { return @{ @"t": t, @"sub": sub }; }
static NSDictionary *kMenuAttrs(BOOL dis) { return @{ NSFontAttributeName: [NSFont systemFontOfSize: 13], NSForegroundColorAttributeName: dis ? [NSColor colorWithCalibratedWhite: 1 alpha: 0.35] : [NSColor whiteColor] }; }
static NSSize MenuSize(NSArray *its)
{
	double w = 0, h = 10; for (NSDictionary *d in its) { if (d[@"sep"]) { h += 11; continue; } h += 22; w = fmax(w, [d[@"t"] sizeWithAttributes: kMenuAttrs(NO)].width + (d[@"sub"] ? 20 : 0)); }
	return NSMakeSize(ceil(w) + 38, h);
}
- (void)rightMouseDown:(NSEvent *)e
{
	int i = [self tileAt: [self screenX: e]]; if (ctxOpen) { ctxOpen = 0; return; } if (i < 0 || fanOpen) return; ctxItem = i; hover = -1;
	NSString *name = tiles[i].label ? @(tiles[i].label) : @""; NSMutableArray *its = [NSMutableArray array];
	int k = items[i].kind; BOOL running = k == DOCK_APP && [runningPaths containsObject: paths[i]];
	if (k == DOCK_APP) {
		BOOL keep = srcKind[i] == 0;
		if (running) { [its addObject: E(name, 0, NO, YES)]; [its addObject: ESep()]; }
		[its addObject: ESub(@"Options", @[ E(@"Keep in Dock", keep ? 4 : 3, keep, NO), E(@"Show in Finder", 7, NO, NO) ])]; [its addObject: ESep()];
		if (!running) [its addObject: E(@"Open", 1, NO, NO)]; else [its addObject: E(@"Quit", 2, NO, NO)];
	} else if (k == DOCK_OTHER) {
		NSDictionary *td = others[srcIdx[i]][@"tile-data"]; int arr = [td[@"arrangement"] intValue], da = [td[@"displayas"] intValue], sa = [td[@"showas"] intValue];
		NSArray *sorts = @[ @"Name", @"Date Added", @"Date Modified", @"Date Created", @"Kind" ]; NSMutableArray *sit = [NSMutableArray array];
		for (int q = 0; q < 5; q++) [sit addObject: E(sorts[q], 101 + q, arr == q + 1, NO)];
		[its addObject: ESub(@"Sort By", sit)];
		[its addObject: ESub(@"Display As", @[ E(@"Stack", 200, da == 0, NO), E(@"Folder", 201, da == 1, NO) ])];
		[its addObject: ESub(@"View Content As", @[ E(@"Automatic", 300, sa == 0, NO), E(@"Fan", 301, sa == 1, NO), E(@"Grid", 302, sa == 2, NO), E(@"List", 303, sa == 3, NO) ])];
		[its addObject: ESep()]; [its addObject: ESub(@"Options", @[ E(@"Remove from Dock", 4, NO, NO), E(@"Show in Finder", 7, NO, NO) ])];
		[its addObject: E([NSString stringWithFormat: @"Open “%@”", name], 5, NO, NO)];
	} else if (k == DOCK_TRASH) { [its addObject: E(@"Empty Trash", 6, NO, !trashFull)]; }
	else return;
	ctxItems = its; ctxOpen = 1; ctxSub = -1; ctxHoverMain = -1; ctxHoverSub = -1; ctxSubItems = nil;
	NSSize ms = MenuSize(its); double top = bar.bottom_margin + bar.bar_h + 8;
	if (!orient) {                                                                       /* above the bar, centred on the tile */
		double x = fmax(8, fmin(screenW - ms.width - 8, slots[i].cx - ms.width / 2));
		ctxMainR = NSMakeRect(x, top, ms.width, ms.height); ctxH = top + ms.height + 40;
	} else {                                                                             /* beside the bar, level with the tile */
		double cy = screenH - (alongBase + slots[i].cx), y = fmax(8, fmin(screenH - ms.height - 8, cy - ms.height / 2));
		ctxMainR = NSMakeRect(orient == 1 ? top : screenW - top - ms.width, y, ms.width, ms.height); ctxH = 0;
	}
}
- (NSRect)rectOfItem:(int)q in:(NSArray *)its menu:(NSRect)r                    /* y up: the first item at the top */
{
	double y = r.origin.y + r.size.height - 5;
	for (int j = 0; j <= q; j++) { double hgt = its[j][@"sep"] ? 11 : 22; y -= hgt; if (j == q) return NSMakeRect(r.origin.x + 5, y, r.size.width - 10, hgt); }
	return NSZeroRect;
}
- (void)ctxHoverAt:(NSPoint)p
{
	ctxHoverMain = -1; ctxHoverSub = -1;
	if (ctxSubItems && NSPointInRect(p, ctxSubR)) { for (int q = 0; q < (int)[ctxSubItems count]; q++) if (!ctxSubItems[q][@"sep"] && NSPointInRect(p, [self rectOfItem: q in: ctxSubItems menu: ctxSubR])) ctxHoverSub = q; ctxHoverMain = ctxSub; return; }
	for (int q = 0; q < (int)[ctxItems count]; q++) if (!ctxItems[q][@"sep"] && NSPointInRect(p, [self rectOfItem: q in: ctxItems menu: ctxMainR])) ctxHoverMain = q;
	if (ctxHoverMain >= 0 && ctxItems[ctxHoverMain][@"sub"]) {
		if (ctxSub != ctxHoverMain) {
			ctxSub = ctxHoverMain; ctxSubItems = ctxItems[ctxSub][@"sub"]; NSSize ss = MenuSize(ctxSubItems); NSRect ir = [self rectOfItem: ctxSub in: ctxItems menu: ctxMainR];
			double sx = ctxMainR.origin.x + ctxMainR.size.width - 4; if (sx + ss.width > screenW) sx = ctxMainR.origin.x - ss.width + 4;
			ctxSubR = NSMakeRect(sx, ir.origin.y + ir.size.height + 5 - ss.height, ss.width, ss.height);
		}
	} else if (ctxHoverMain >= 0) { ctxSub = -1; ctxSubItems = nil; }
}
- (void)drawMenu:(NSArray *)its in:(NSRect)r hover:(int)hv
{
	CGContextRef c = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	NSBezierPath *bp = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 10 yRadius: 10];
	CGContextSaveGState(c); CGContextSetShadowWithColor(c, CGSizeMake(0, -8), 22, CGColorCreateGenericGray(0, 0.45));
	[[NSColor colorWithCalibratedWhite: 0.16 alpha: 0.94] setFill]; [bp fill]; CGContextRestoreGState(c);
	[[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] setStroke]; [bp setLineWidth: 1]; [bp stroke];
	for (int q = 0; q < (int)[its count]; q++) {
		NSDictionary *d = its[q]; NSRect ir = [self rectOfItem: q in: its menu: r];
		if (d[@"sep"]) { [[NSColor colorWithCalibratedWhite: 1 alpha: 0.16] setFill]; NSRectFill(NSMakeRect(ir.origin.x + 4, ir.origin.y + 5, ir.size.width - 8, 1)); continue; }
		BOOL dis = [d[@"dis"] boolValue];
		if (q == hv && !dis) { [[NSColor colorWithCalibratedRed: 0.04 green: 0.52 blue: 1 alpha: 1] setFill]; [[NSBezierPath bezierPathWithRoundedRect: ir xRadius: 5 yRadius: 5] fill]; }
		NSDictionary *at = kMenuAttrs(dis); NSSize ts = [d[@"t"] sizeWithAttributes: at];
		[d[@"t"] drawAtPoint: NSMakePoint(ir.origin.x + 24, ir.origin.y + (ir.size.height - ts.height) / 2) withAttributes: at];
		if ([d[@"on"] boolValue]) [@"✓" drawAtPoint: NSMakePoint(ir.origin.x + 7, ir.origin.y + (ir.size.height - ts.height) / 2) withAttributes: at];
		if (d[@"sub"]) [@"›" drawAtPoint: NSMakePoint(ir.origin.x + ir.size.width - 14, ir.origin.y + (ir.size.height - ts.height) / 2) withAttributes: at];
	}
}
- (void)drawContext
{
	[self drawMenu: ctxItems in: ctxMainR hover: ctxHoverMain];
	if (ctxSubItems) [self drawMenu: ctxSubItems in: ctxSubR hover: ctxHoverSub];
}
- (BOOL)ctxClick:(NSPoint)p                                                    /* a click while a menu is open: YES when it was consumed */
{
	[self ctxHoverAt: p];
	NSDictionary *d = nil; if (ctxSubItems && NSPointInRect(p, ctxSubR) && ctxHoverSub >= 0) d = ctxSubItems[ctxHoverSub];
	else if (!(ctxSubItems && NSPointInRect(p, ctxSubR)) && ctxHoverMain >= 0 && !ctxItems[ctxHoverMain][@"sub"]) d = ctxItems[ctxHoverMain];
	else if (NSPointInRect(p, ctxMainR) || (ctxSubItems && NSPointInRect(p, ctxSubR))) return YES;       /* on a title, a separator or a submenu: stays open */
	ctxOpen = 0; if (d && ![d[@"dis"] boolValue] && d[@"c"]) { NSMenuItem *mi = [[NSMenuItem alloc] init]; [mi setTag: [d[@"c"] intValue]]; [self ctx: mi]; }
	return YES;
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
		[v computeWindow]; NSWindow *w = [[NSWindow alloc] initWithContentRect: [v stateFrame] styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		if (getenv("DOCK_TEST")) { [w setBackgroundColor: [NSColor greenColor]]; } else { [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; } [w setHasShadow: NO]; [w setLevel: getenv("DOCK_LEVEL") ? atoi(getenv("DOCK_LEVEL")) : 20]; [w setHidesOnDeactivate: NO]; [w setCanHide: NO]; [w setContentView: v]; [w setAcceptsMouseMovedEvents: YES];
		[w orderFrontRegardless];
		[app run];
	}
	return 0;
}
