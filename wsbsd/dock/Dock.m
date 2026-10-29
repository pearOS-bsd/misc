/* Dock.app for wsbsd: the Dock of the desktop. A borderless window at the bottom of the screen draws the bar with DockRender; the layout (with magnification) comes from dock_layout.c, the genie from genie.c.
 * The items are the persistent applications of ~/Library/Preferences/com.apple.dock.plist (or a default set), the running ones get a dot. */
#import <objc/runtime.h>
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

/* the context menu of a tile is an NSMenu (the AppKit menu of the theme, glass and all): the items of the old hand-drawn menu are turned into NSMenuItems whose tag is the command; the server puts a menu at the pointer, so it is moved above the bar once it is on screen */
@interface DockMenuFit : NSObject { NSMenu *menu; NSPoint origin; int n; } - (id)initFor:(NSMenu *)m at:(NSPoint)o; @end
@implementation DockMenuFit
- (id)initFor:(NSMenu *)m at:(NSPoint)o { if ((self = [super init])) { menu = m; origin = o; [self performSelector: @selector(fit) withObject: nil afterDelay: 0.03 inModes: @[ NSEventTrackingRunLoopMode, NSDefaultRunLoopMode ]]; } return self; }
- (void)fit { NSWindow *mw = [[menu menuRepresentation] window]; if (!mw || ![mw isVisible]) { if (++n < 15) [self performSelector: @selector(fit) withObject: nil afterDelay: 0.03 inModes: @[ NSEventTrackingRunLoopMode, NSDefaultRunLoopMode ]]; return; } NSRect f = [mw frame]; f.origin = NSMakePoint(fmax(8, origin.x - f.size.width / 2), origin.y); [mw setFrameOrigin: f.origin]; }
@end
static NSMenu *NativeMenu(NSArray *its, id target)
{
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; [m setAutoenablesItems: NO];
	for (NSDictionary *d in its) {
		if (d[@"sep"]) { [m addItem: [NSMenuItem separatorItem]]; continue; }
		NSMenuItem *it = [m addItemWithTitle: d[@"t"] action: (d[@"c"] && [d[@"c"] intValue] > 0) ? @selector(ctx:) : NULL keyEquivalent: @""]; [it setTarget: target]; [it setTag: [d[@"c"] intValue]]; [it setState: [d[@"on"] boolValue] ? NSOnState : NSOffState]; [it setEnabled: ![d[@"dis"] boolValue] && (d[@"sub"] || [d[@"c"] intValue] > 0)];
		if (d[@"sub"]) [it setSubmenu: NativeMenu(d[@"sub"], target)];
	}
	return m;
}
/* View content as > List: the stack as a plain NSMenu (measured on the Mac: a glass menu above the tile, the names in their sort order from the top, a 16 pt icon before each, folders with a submenu arrow, then a separator, "Options" (submenu) and "Open in Finder"; a long folder fills the screen height and scrolls, here it is cut to the rows that fit). */
@interface DockListMenu : NSObject <NSMenuDelegate> { @public NSString *dir; NSArray *names; int maxRows; void (^open)(NSString *); void (^command)(int); } - (NSMenu *)menu; @end
@implementation DockListMenu
- (void)pick:(NSMenuItem *)it { if (open) open([it representedObject]); }
- (void)opt:(NSMenuItem *)it { if (command) command((int)[it tag]); }
- (NSMenu *)menuForDir:(NSString *)d names:(NSArray *)nm rows:(int)rows
{
	NSMenu *m = [[NSMenu alloc] initWithTitle: @""]; [m setAutoenablesItems: NO]; NSFileManager *fm = [NSFileManager defaultManager]; int n = 0;
	for (NSString *name in nm) {
		if (n++ >= rows) break; NSString *p = [d stringByAppendingPathComponent: name]; BOOL isDir = NO; [fm fileExistsAtPath: p isDirectory: &isDir];
		NSMenuItem *it = [m addItemWithTitle: name action: @selector(pick:) keyEquivalent: @""]; [it setTarget: self]; [it setRepresentedObject: p];
		NSImage *ic = [[NSWorkspace sharedWorkspace] iconForFile: p]; [ic setSize: NSMakeSize(16, 16)]; [it setImage: ic];
		BOOL pkg = isDir && [[NSWorkspace sharedWorkspace] isFilePackageAtPath: p];
		if (isDir && !pkg) { NSMenu *sub = [[NSMenu alloc] initWithTitle: p]; [sub setDelegate: self]; [it setSubmenu: sub]; }
	}
	return m;
}
- (void)menuNeedsUpdate:(NSMenu *)sub { if ([sub numberOfItems]) return; NSString *p = [sub title]; NSMutableArray *v = [NSMutableArray array]; for (NSString *nm in [[NSFileManager defaultManager] contentsOfDirectoryAtPath: p error: NULL]) if (![nm hasPrefix: @"."]) [v addObject: nm];
	[v sortUsingSelector: @selector(localizedCaseInsensitiveCompare:)]; NSMenu *m = [self menuForDir: p names: v rows: maxRows]; for (NSMenuItem *it in [m itemArray]) { [m removeItem: it]; [sub addItem: it]; }
	if (![sub numberOfItems]) { NSMenuItem *e = [sub addItemWithTitle: @"Empty" action: NULL keyEquivalent: @""]; [e setEnabled: NO]; } }
- (NSMenu *)menu
{
	NSMenu *m = [self menuForDir: dir names: names rows: maxRows]; [m addItem: [NSMenuItem separatorItem]];
	NSMenuItem *o = [m addItemWithTitle: @"Options" action: NULL keyEquivalent: @""]; NSMenu *os = [[NSMenu alloc] initWithTitle: @""]; [os setAutoenablesItems: NO]; for (NSArray *e in @[ @[ @"Remove from Dock", @4 ], @[ @"Show in Finder", @7 ] ]) { NSMenuItem *oi = [os addItemWithTitle: e[0] action: @selector(opt:) keyEquivalent: @""]; [oi setTarget: self]; [oi setTag: [e[1] intValue]]; } [o setSubmenu: os];
	NSMenuItem *f = [m addItemWithTitle: @"Open in Finder" action: @selector(pick:) keyEquivalent: @""]; [f setTarget: self]; [f setRepresentedObject: dir];
	return m;
}
@end
/* The Downloads-style stack as a grid (View content as > Grid). Measured on the Mac (AX of the Dock, a stack of 332 items): a panel 1306 x 1114 centred on the tile (1306 = 12 columns of 106 + 34), its bottom 10 under the top of the bar, the title ("Downloads", 13 pt bold, 73 x 19) 7 under its top, a scroll
 * area of 1272 wide from 17 inside the left edge and 30 under the top, cells of 106 x 106 without gaps (the icon about 52 px, 10 under the cell's top; the name in one line below it, shortened in the middle), rows 106 apart; the panel is as high as 10 rows (54 more than the cells). The material is
 * the menu glass (mode 5, corners about 22) with the menu's shadow. Not measured: the highlight of a hovered cell, the look of an empty folder, the scroller, the animation of opening. */
@interface DockGridView : NSView { @public NSArray *names; NSString *dir; NSMutableDictionary *icons; int cols; void (^pick)(NSString *); } @end
@implementation DockGridView
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (void)drawRect:(NSRect)dirty
{
	CGContextRef c = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort]; if (!icons) icons = [NSMutableDictionary dictionary];
	NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setAlignment: NSCenterTextAlignment]; [ps setLineBreakMode: NSLineBreakByTruncatingMiddle];
	NSDictionary *at = @{ NSFontAttributeName: [NSFont systemFontOfSize: 11], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite: 1 alpha: 0.92], NSParagraphStyleAttributeName: ps };
	for (NSUInteger i = 0; i < [names count]; i++) {
		NSRect cell = NSMakeRect((i % cols) * 106, (i / cols) * 106, 106, 106); if (!NSIntersectsRect(cell, dirty)) continue;
		NSString *nm = names[i], *p = [dir stringByAppendingPathComponent: nm]; NSValue *iv = icons[nm];
		if (!iv) { CGImageRef im = LSIconCreateForPath(p, 128); iv = [NSValue valueWithPointer: im]; icons[nm] = iv; }
		CGImageRef im = (CGImageRef)[iv pointerValue];
		if (im) { CGRect ir = CGRectMake(cell.origin.x + 27, cell.origin.y + 10, 52, 52); CGContextSaveGState(c); CGContextTranslateCTM(c, ir.origin.x, ir.origin.y + ir.size.height); CGContextScaleCTM(c, 1, -1); CGContextDrawImage(c, CGRectMake(0, 0, ir.size.width, ir.size.height), im); CGContextRestoreGState(c); }
		[nm drawInRect: NSMakeRect(cell.origin.x + 3, cell.origin.y + 72, 100, 16) withAttributes: at];
	}
}
- (void)mouseDown:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; NSInteger col = (NSInteger)(p.x / 106), row = (NSInteger)(p.y / 106), i = row * cols + col; if (col >= 0 && col < cols && i >= 0 && i < (NSInteger)[names count] && pick) pick(names[i]); }
@end
@interface DockGridWindow : NSWindow @end
@implementation DockGridWindow
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)resignKeyWindow { [super resignKeyWindow]; [self orderOut: nil]; }
- (void)keyDown:(NSEvent *)e { if ([[e characters] isEqual: @"\x1b"]) [self orderOut: nil]; else [super keyDown: e]; }
@end
@interface DockGridTitle : NSView { @public NSString *title; } @end
@implementation DockGridTitle
- (BOOL)isFlipped { return YES; }
- (void)drawRect:(NSRect)r { NSMutableParagraphStyle *ps = [[NSMutableParagraphStyle alloc] init]; [ps setAlignment: NSCenterTextAlignment]; [title ?: @"" drawInRect: NSMakeRect(0, 7, [self bounds].size.width, 19) withAttributes: @{ NSFontAttributeName: [NSFont boldSystemFontOfSize: 13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite: 1 alpha: 0.85], NSParagraphStyleAttributeName: ps }]; }
@end
static DockGridWindow *gGrid; static int gGridTile;
/* shows the grid of a folder: tileCx the centre of the tile (screen x), barTop the top of the bar (screen y, y up), the names already sorted */
static void ShowDockGrid(NSString *title, NSString *dir, NSArray *names, double tileCx, double barTop, void (^pick)(NSString *))
{
	NSRect scr = [[NSScreen mainScreen] frame]; int cols = (int)MIN(12.0, floor((scr.size.width - 60) / 106)); if (cols < 3) cols = 3; int rowsAll = ((int)[names count] + cols - 1) / cols; if (rowsAll < 1) rowsAll = 1;
	double bottom = barTop + 16, topMax = scr.size.height - 0.172 * scr.size.height, maxH = MAX(160.0, topMax - bottom); int rows = (int)MIN((double)rowsAll, floor((maxH - 54) / 106)); if (rows < 1) rows = 1;
	double w = cols * 106 + 34, h = rows * 106 + 54; double x = MAX(8, MIN(scr.size.width - w - 8, tileCx - w / 2));
	NSRect f = NSMakeRect(x, bottom, w, h);
	if (!gGrid) { gGrid = [[DockGridWindow alloc] initWithContentRect: f styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO]; [gGrid setOpaque: NO]; [gGrid setBackgroundColor: [NSColor clearColor]]; [gGrid setHasShadow: NO]; [gGrid setLevel: 25]; [gGrid setHidesOnDeactivate: NO]; }
	NSView *root = [[NSView alloc] initWithFrame: NSMakeRect(0, 0, w, h)]; [gGrid setContentView: root]; [gGrid setFrame: f display: YES];
	DockGridTitle *tv = [[DockGridTitle alloc] initWithFrame: NSMakeRect(0, h - 30, w, 30)]; tv->title = title; [root addSubview: tv];
	NSScrollView *sv = [[NSScrollView alloc] initWithFrame: NSMakeRect(17, 24, cols * 106, rows * 106)]; [sv setHasVerticalScroller: YES]; [sv setDrawsBackground: NO]; [sv setBorderType: NSNoBorder];
	DockGridView *gv = [[DockGridView alloc] initWithFrame: NSMakeRect(0, 0, cols * 106, rowsAll * 106)]; gv->names = names; gv->dir = dir; gv->cols = cols; gv->pick = ^(NSString *nm) { [gGrid orderOut: nil]; if (pick) pick(nm); };
	[sv setDocumentView: gv]; [root addSubview: sv];
	ws_conn *wc = ws_connect(NULL); if (wc) { ws_win gw = { .id = (ws_wid)[gGrid windowNumber], .px = NULL }; ws_win_glass_slot(wc, &gw, 1, (ws_rect){ 0, 0, (int)w, (int)h }, 22, 5); ws_win_shadow(wc, &gw, 22, 2); ws_disconnect(wc); }
	[NSApp activateIgnoringOtherApps: YES]; [gGrid makeKeyAndOrderFront: nil]; [gGrid makeFirstResponder: gv];
}
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
	NSArray *ctxItems; int ctxGlass, ctxGlassSet[2]; ws_rect ctxGlassRect[2]; int ctxOpen, ctxSub, ctxHoverMain, ctxHoverSub; NSRect ctxMainR, ctxSubR; NSArray *ctxSubItems; double ctxH;
	double poofT0; NSPoint poofAt;
	int ctxItem, dragCand, dragItem, dragging; double dragStartX; int trashFull;
	NSTrackingRectTag trackTag; double pointer; int hover; double scale[MAXITEMS]; double bounceStart[MAXITEMS]; NSTimer *timer; uint64_t drawnHash; BOOL drawnOnce; double screenW, screenH, screenLen, alongBase; int orient; DockFan fan; int fanOpen; double fanStart, fanClose; NSMutableArray *fanStore;
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
	[[NSDistributedNotificationCenter defaultCenter] addObserver: self selector: @selector(badgeNote:) name: @"com.wsbsd.dock.badge" object: nil];
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
	{ NSMutableArray *kept = [NSMutableArray array]; for (NSDictionary *t in apps) if (![TilePath(t) hasSuffix: @"/Finder.app"] && ![TilePath(t) hasSuffix: @"/Finder.app/"]) [kept addObject: t]; [apps setArray: kept]; }       /* the Finder's tile is not in the plist: the Dock puts it first itself, and it cannot be removed */
	for (NSDictionary *t in prefs[@"persistent-others"]) [others addObject: [t mutableCopy]];
	BOOL noPrefs = ![apps count] && !prefs[@"persistent-apps"];
	if (noPrefs) {                          /* no preferences: the default set of this system */
		struct { const char *label, *path; } defs[] = { { "Terminal", "/System/Applications/Utilities/Terminal.app" },
			{ "UITest", "/Applications/UITest.app" }, { "Keyboard Setup Assistant", "/System/Applications/Utilities/Keyboard Setup Assistant.app" } };
		for (size_t i = 0; i < sizeof defs / sizeof defs[0]; i++) [apps addObject: [self tileForPath: @(defs[i].path) label: @(defs[i].label)]];
		[others addObject: [@{ @"tile-type": @"directory-tile", @"tile-data": @{ @"file-data": @{ @"_CFURLString": [@"file://" stringByAppendingString: [[NSHomeDirectory() stringByAppendingPathComponent: @"Downloads"] stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLPathAllowedCharacterSet]]], @"_CFURLStringType": @0 }, @"file-label": @"Downloads", @"arrangement": @2, @"showas": @(getenv("DOCK_SHOWAS") ? atoi(getenv("DOCK_SHOWAS")) : 1), @"displayas": @0 } } mutableCopy]];
	}
	if ([[NSFileManager defaultManager] fileExistsAtPath: @"/System/Library/CoreServices/Finder.app"]) [apps insertObject: [self tileForPath: @"/System/Library/CoreServices/Finder.app" label: @"Finder"] atIndex: 0];
	{ NSMutableArray *kept = [NSMutableArray array]; for (NSDictionary *t in apps) if (![TilePath(t) hasSuffix: @"/Apps.app"]) [kept addObject: t]; [apps setArray: kept]; }       /* "Apps" (Applications: the Launchpad of macOS 27) is the second tile, always, and is not saved */
	[apps insertObject: [self tileForPath: @"/System/Applications/Apps.app" label: @"Apps"] atIndex: MIN((NSUInteger)1, [apps count])];
}
- (NSMutableDictionary *)tileForPath:(NSString *)path label:(NSString *)label
{
	NSString *u = [@"file://" stringByAppendingString: [path stringByAddingPercentEncodingWithAllowedCharacters: [NSCharacterSet URLPathAllowedCharacterSet]]];
	return [@{ @"GUID": @(arc4random()), @"tile-type": @"file-tile", @"tile-data": @{ @"file-data": @{ @"_CFURLString": [u stringByAppendingString: @"/"], @"_CFURLStringType": @15 }, @"file-label": label ?: [[path lastPathComponent] stringByDeletingPathExtension], @"file-type": @41, @"dock-extra": @NO } } mutableCopy];
}
- (void)savePrefs
{
	{ NSMutableArray *save = [NSMutableArray array]; for (NSDictionary *t in apps) if (![TilePath(t) hasSuffix: @"/Finder.app"] && ![TilePath(t) hasSuffix: @"/Apps.app"]) [save addObject: t]; prefs[@"persistent-apps"] = save; } prefs[@"persistent-others"] = others;
	NSString *dir = [[self prefsPath] stringByDeletingLastPathComponent]; [[NSFileManager defaultManager] createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL];
	[prefs writeToFile: [self prefsPath] atomically: YES];
}
/* the running applications: executables inside a .app bundle in the process list */
- (void)scanProcesses
{
	NSMutableDictionary *pm = [NSMutableDictionary dictionary];
	FILE *f = popen("ps -axww -o pid= -o command= 2>/dev/null", "r");
	if (f) {
		char line[2048];
		while (fgets(line, sizeof line, f)) {
			char *prog = strchr(line, ' '); while (prog && *prog == ' ') prog++; while (prog && *prog >= '0' && *prog <= '9') prog++; while (prog && *prog == ' ') prog++;          /* the program of the line: a bare executable (Terminal-gnustep) stands for the bundle of that name */
			if (prog) { char cmd[1024]; snprintf(cmd, sizeof cmd, "%s", prog); char *sp = strpbrk(cmd, " \n"); if (sp) *sp = 0; char *bn = strrchr(cmd, '/'); bn = bn ? bn + 1 : cmd; NSString *nm = [NSString stringWithUTF8String: bn]; if ([nm hasSuffix: @"-gnustep"]) nm = [nm substringToIndex: [nm length] - 8]; if ([nm length] && !pm[[@"name:" stringByAppendingString: nm]]) pm[[@"name:" stringByAppendingString: nm]] = @(atoi(line)); }
			char *mark = strstr(line, ".app/Contents/MacOS/");
			if (!mark) { mark = strstr(line, ".app/"); if (mark) { char *e = mark + 5; while (*e && *e != ' ' && *e != '\n') { if (*e == '/') { mark = NULL; break; } e++; } } }        /* the GNUstep layout: the program lies next to the bundle's other files */
			if (!mark) continue;
			int pid = atoi(line); *mark = 0; char *start = line; while (*start == ' ') start++; while (*start >= '0' && *start <= '9') start++; while (*start == ' ') start++;
			NSString *bp = [[NSString stringWithUTF8String: start] stringByAppendingString: @".app"]; if (!pm[bp]) pm[bp] = @(pid);
		}
		pclose(f);
	}
	if (getenv("DOCK_LOG")) NSLog(@"dock: running %@", pm);
	runningPids = pm;
	NSMutableSet *rp = [NSMutableSet set]; for (NSString *k in pm) if (![k hasPrefix: @"name:"]) [rp addObject: k]; runningPaths = rp;
}
/* the process of an application tile: its bundle's executable, or a program of the bundle's name (Terminal-gnustep for Terminal.app) */
- (int)pidOfApp:(NSString *)path
{
	NSNumber *n = runningPids[path]; if (n) return [n intValue];
	NSString *base = [[path lastPathComponent] stringByDeletingPathExtension];
	n = runningPids[[@"name:" stringByAppendingString: base]] ?: runningPids[[@"name:" stringByAppendingString: [base stringByReplacingOccurrencesOfString: @" " withString: @""]]];
	return n ? [n intValue] : 0;
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
		NSString *path = TilePath(t); if (![path length] || (![fm fileExistsAtPath: path] && ![path hasSuffix: @"/Apps.app"])) continue;        /* an application that is not installed has no tile here */
		[pinned addObject: path]; [labelStore addObject: TileLabel(t, path)];
		PUSH(DOCK_APP, [[labelStore lastObject] UTF8String], [path hasSuffix: @"/Finder.app"] ? "finder" : [path hasSuffix: @"/Terminal.app"] ? "terminal" : [path hasSuffix: @"/Apps.app"] ? "launchpad" : "generic", path, 0, (int)k);       /* the drawn glyphs stand in for the icon when the bundle has none (the Finder.app of an image has no resources) */
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
	for (int i = 0; i < n; i++) { scale[i] = 1; bounceStart[i] = 0; if (items[i].kind == DOCK_APP) { CGImageRef ic = [self iconForPath: paths[i]]; if (ic) tiles[i].icon = ic; tiles[i].badge = [badgeStore[paths[i]] intValue]; } }
	scanKey = [[[runningPaths allObjects] sortedArrayUsingSelector: @selector(compare:)] componentsJoinedByString: @"|"];
}
- (BOOL)wide { return fanOpen || ctxOpen || [self poofing]; }
- (BOOL)poofing { return poofT0 > 0 && Now() - poofT0 < 0.6; }
- (double)originX { return [self wide] ? (orient ? -alongBase : 0) : winX; }          /* the along-coordinate of the window's start */
/* the window's frame for the state: the bar's own window, or the whole screen while a fan or a menu is open */
- (NSRect)stateFrame
{
	double thick = (autohide && hideFrac >= 1) ? 2 : orient ? 320 : 170;
	if ([self poofing] && !fanOpen && !ctxOpen) return NSMakeRect(0, 0, screenW, screenH);
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
/* the minimize effect of the preference "mineffect": the genie, or "scale" (the window shrinks straight into the tile) */
- (int)effectMesh:(const double *)win icon:(const double *)icon progress:(float)p cols:(int *)cols rows:(int *)rows done:(float *)done
{
	int dir = orient ? 2 + orient : 1;
	if (![prefs[@"mineffect"] isEqual: @"scale"]) return genie_mesh(win, icon, p, dir, genieMesh, cols, rows, done);
	static float id[GENIE_MAX_FLOATS]; int c0, r0; float d0;                       /* the corners of the untouched window, in the mesh's own conventions */
	if (!genie_mesh(win, icon, 0.0001f, dir, id, &c0, &r0, &d0) || c0 < 2 || r0 < 2) return genie_mesh(win, icon, p, dir, genieMesh, cols, rows, done);
	int cc[4] = { 0, c0 - 1, 0, c0 - 1 }, rr[4] = { 0, 0, r0 - 1, r0 - 1 };
	for (int k = 0; k < 4; k++) {
		const float *q = &id[(rr[k] * c0 + cc[k]) * 4]; float *o = &genieMesh[k * 4];
		double nx = win[2] > 0 ? (q[2] - win[0]) / win[2] : 0, ny = win[3] > 0 ? (q[3] - win[1]) / win[3] : 0;
		o[0] = q[0]; o[1] = q[1]; o[2] = (float)(q[2] + (icon[0] + nx * icon[2] - q[2]) * p); o[3] = (float)(q[3] + (icon[1] + ny * icon[3] - q[3]) * p);
	}
	*cols = 2; *rows = 2; *done = p; return 16;
}
- (void)stepMini
{
	for (int k = 0; k < nmini; k++) {
		MiniWin *mw = &mini[k]; if (mw->phase == 2 || !wsc) continue;
		double p = (Now() - mw->t0) / (mw->phase == 1 ? 0.75 : 0.5); if (p > 1) p = 1; if (mw->phase == 3) p = 1 - p;
		int ti = mw->appItem >= 0 ? mw->appItem : mw->item; if (ti < 0 || ti >= n) continue;
		const DockSlot *sl = &slots[ti]; ws_win w = { .id = mw->wid, .px = NULL };
		double icon[4]; [self iconRect: ti into: icon]; int cols, rows; float done;
		int nf = [self effectMesh: mw->wr icon: icon progress: (float)p cols: &cols rows: &rows done: &done];
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
	if ([self effectMesh: mw->wr icon: icon progress: 1.0f cols: &cols rows: &rows done: &done]) ws_win_warp(wsc, &w, cols, rows, genieMesh);      /* collapsed into the tile before it is shown */
	ws_win_order(wsc, &w, WS_ABOVE, 0);
	mw->phase = 3; mw->t0 = Now();
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.dock.restore" object: nil userInfo: @{ @"wid": @(mw->wid) } deliverImmediately: YES];
}
/* ---- hot corners, as the Dock decides them (decompiled from HotCorners::_handleEvent:location:flags: and _cornerActionForMouseEnter:): the four wvous-<tl|tr|bl|br>-corner preferences hold an action
 * (1 none, 2 Mission Control, 3 application windows, 4 Desktop, 5 start the screen saver, 6 do not start it, 7 Dashboard, 10 put the display to sleep, 11 Launchpad, 12 Notification Center, 13 lock the screen, 14 Quick Note);
 * entering the corner's region runs the action, 5 and 10 only after 0.5 s in the corner, 6 for as long as the pointer stays; leaving the region cancels what is pending */
static int hcInside = -1, hcDesktop; static double hcEnter; static int hcPending; static NSMutableArray *hcHidden;
static int HCAction(NSDictionary *prefs, int corner)
{
	static const char *k[4] = { "wvous-tl-corner", "wvous-tr-corner", "wvous-bl-corner", "wvous-br-corner" };
	id v = prefs[@(k[corner])]; return v ? [v intValue] : 1;
}
- (void)runCornerAction:(int)a
{
	NSLog(@"hotcorners: handling mouse enter action %d", a);
	if (a == 4 && wsc) {                                                       /* Desktop: every other window steps aside, the next time they come back */
		uint32_t ids[256]; int total = 0; ws_win me = { .id = (ws_wid)[[self window] windowNumber], .px = NULL }; int myOwner = 0, rights = 0; ws_win_get_owner(wsc, &me, &myOwner, &rights);
		if (!hcDesktop) {
			hcHidden = [NSMutableArray array]; if (ws_win_list(wsc, 0, 1, ids, 256, &total) == 0) for (int i = 0; i < total && i < 256; i++) {
				ws_win w = { .id = ids[i], .px = NULL }; int lv = 0, ow = 0; ws_win_get_level(wsc, &w, &lv); ws_win_get_owner(wsc, &w, &ow, &rights);
				if (lv == 0 && ow != myOwner) { [hcHidden addObject: @(ids[i])]; ws_win_order(wsc, &w, WS_OUT, 0); }
			}
			hcDesktop = 1;
		} else { for (NSNumber *n in hcHidden) { ws_win w = { .id = (ws_wid)[n unsignedIntValue], .px = NULL }; ws_win_order(wsc, &w, WS_ABOVE, 0); } hcHidden = nil; hcDesktop = 0; }
		return;
	}
	[[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.hotcorner" object: nil userInfo: @{ @"action": @(a) } deliverImmediately: YES];
}
- (void)pollHotCorners
{
	if (!wsc) return; int px, py; if (ws_cursor_position(wsc, &px, &py)) return;
	static int dbg; if (getenv("DOCK_LOG") && (dbg++ % 120) == 0) NSLog(@"hotcorners: pointer %d,%d tl=%d br=%d", px, py, HCAction(prefs, 0), HCAction(prefs, 3));
	int corner = -1; if (py <= 1) corner = px <= 1 ? 0 : px >= screenW - 2 ? 1 : -1; else if (py >= screenH - 2) corner = px <= 1 ? 2 : px >= screenW - 2 ? 3 : -1;
	if (corner < 0) {                                                          /* left the region: what waits is cancelled, a "keep the screen saver away" ends */
		if (hcInside >= 0 && HCAction(prefs, hcInside) == 6) [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.hotcorner" object: nil userInfo: @{ @"action": @6, @"exit": @YES } deliverImmediately: YES];
		hcInside = -1; hcPending = 0; return;
	}
	if (corner == hcInside) {
		if (hcPending && Now() - hcEnter >= 0.5) { int a = hcPending; hcPending = 0; [self runCornerAction: a]; }
		return;
	}
	hcInside = corner; hcEnter = Now(); int a = HCAction(prefs, corner);
	if (a == 1) return;
	if (a == 5 || a == 10) { hcPending = a; return; }
	[self runCornerAction: a];
}
/* an application's Dock badge (NSDockTile badgeLabel): the notification carries the application's path and the number, 0 clears it */
static NSMutableDictionary *badgeStore;
- (void)badgeNote:(NSNotification *)n
{
	NSString *p = [n userInfo][@"path"]; if (![p length]) return; if (!badgeStore) badgeStore = [NSMutableDictionary dictionary];
	badgeStore[p] = [n userInfo][@"count"] ?: @0; if (getenv("DOCK_LOG")) NSLog(@"dock: badge %@ -> %@ (tiles: %@)", p, badgeStore[p], [paths description]); for (int i = 0; i < self->n; i++) if (items[i].kind == DOCK_APP && [paths[i] isEqualToString: p]) tiles[i].badge = [badgeStore[p] intValue];
	[self setNeedsDisplay: YES];
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
	[self stepAutohide]; [self pollHotCorners];
	for (int i = 0; i < n; i++) {
		int pid = [pids[i] intValue]; tiles[i].running = (pid > 0 && kill(pid, 0) == 0) || (items[i].kind == DOCK_APP && [self pidOfApp: paths[i]] > 0);
		if (bounceStart[i] > 0) {                                                  /* the launch bounce: three arcs of decreasing height, 0.6 s each... */
			double t = Now() - bounceStart[i], dur = 2.0; if (t > dur) { bounceStart[i] = 0; tiles[i].bounce = 0; }
			else { double ph = fmod(t, 0.66) / 0.66; tiles[i].bounce = (float)(4 * ph * (1 - ph) * (1.0 - t / dur) * 0.75); }
		}
	}
	if (ctxOpen && wsc) { int px, py; if (ws_cursor_position(wsc, &px, &py) == 0) [self ctxHoverAt: NSMakePoint(px, screenH - py)]; pointer = -1; hover = -1; }
	if (wsc && !fanOpen && !ctxOpen && ![self poofing]) {                       /* the pointer from the window server: the bar unzooms when it leaves (tracking events are not reliable) */
		int px, py; if (ws_cursor_position(wsc, &px, &py) == 0) {
			NSRect wf = [[self window] frame]; double top = screenH - (wf.origin.y + wf.size.height);
			if (hideFrac < 1 && py >= top && py < top + wf.size.height && px >= wf.origin.x && px < wf.origin.x + wf.size.width) { pointer = orient ? py - alongBase : px; hover = [self tileAt: pointer]; } else { pointer = -1; hover = -1; }
		}
	}
	[self relayout];
	if (wsc && !fanOpen && !(autohide && hideFrac >= 1)) { double ox = ctxOpen ? 0 : winX; (void)ox;                      /* the glass of the bar: the window server blurs and bends what is behind the bar's rounded rectangle (the window is larger than the bar) */
		ws_win gw = { .id = (ws_wid)[[self window] windowNumber], .px = NULL }; double wh = [[self window] frame].size.height;
		ws_rect gr = { (int)floor(bar.bar_x - [self originX]), (int)floor(wh - (bar.bottom_margin + bar.bar_h)), (int)ceil(bar.bar_w), (int)ceil(bar.bar_h) };
		if (orient) { double ww = [[self window] frame].size.width; gr = (ws_rect){ (int)floor(orient == 1 ? bar.bottom_margin : ww - (bar.bottom_margin + bar.bar_h)), (int)floor(bar.bar_x - [self originX]), (int)ceil(bar.bar_h), (int)ceil(bar.bar_w) }; }
		if (gr.x != glassRect.x || gr.y != glassRect.y || gr.w != glassRect.w || gr.h != glassRect.h || !glassOn) { ws_win_glass(wsc, &gw, gr, 18, 1); glassRect = gr; glassOn = 1; }
	} else if (wsc && glassOn) { ws_win_glass(wsc, &(ws_win){ .id = (ws_wid)[[self window] windowNumber], .px = NULL }, (ws_rect){ 0, 0, 0, 0 }, 0, 0); glassOn = 0; }
	if (wsc) {                                                                  /* the menus' material: slots 1 (menu) and 2 (submenu) of the window's glass, mode 5 = the context menu as measured on the Mac */
		ws_win gw = { .id = (ws_wid)[[self window] windowNumber], .px = NULL }; double wh = [[self window] frame].size.height;
		for (int k = 0; k < 2; k++) {
			NSRect r = k == 0 ? ctxMainR : ctxSubR; BOOL on = ctxOpen && (k == 0 || ctxSubItems);
			ws_rect gr = on ? (ws_rect){ (int)r.origin.x, (int)floor(wh - (r.origin.y + r.size.height)), (int)r.size.width, (int)r.size.height } : (ws_rect){ 0, 0, 0, 0 };
			if (!on && !ctxGlassSet[k]) continue;
			if (on && ctxGlassSet[k] && !memcmp(&gr, &ctxGlassRect[k], sizeof gr)) continue;
			ws_win_glass_slot(wsc, &gw, k + 1, gr, 12, on ? 5 : 0); ctxGlassSet[k] = on; ctxGlassRect[k] = gr;
		}
		ctxGlass = ctxGlassSet[0];
	}
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
	[self redrawIfChanged: f];
}
/* the view is redrawn only when something it shows has changed (the window server blends and blurs the whole window again for every frame it gets): the hash covers the tiles, the slots, the bar and the state of the menus, fans and grids; while an animation without a state of its own runs (fan, menu, poof, bounce, minimising) every tick draws */
- (void)redrawIfChanged:(NSRect)f
{
	uint64_t h = 1469598103934665603ULL;
#define MIX(v) do { double d_ = (double)(v); uint64_t u_; memcpy(&u_, &d_, 8); h = (h ^ u_) * 1099511628211ULL; } while (0)
	BOOL busy = fanOpen || ctxOpen || [self poofing] || (gGrid && [gGrid isVisible]);
	for (int i = 0; i < n; i++) { MIX(tiles[i].running); MIX(tiles[i].badge); MIX(tiles[i].bounce); MIX((uintptr_t)tiles[i].icon); MIX((uintptr_t)tiles[i].glyph); MIX(slots[i].x); MIX(slots[i].w); MIX(slots[i].cx); MIX(slots[i].scale); MIX(slots[i].art); if (tiles[i].bounce > 0) busy = YES; }
	for (int k = 0; k < nmini; k++) if (mini[k].phase != 2) busy = YES;
	MIX(n); MIX(hover); MIX(hideFrac); MIX(trashFull); MIX(bar.bar_x); MIX(bar.bar_w); MIX(bar.bar_h); MIX(bar.bottom_margin); MIX(bar.art_rest); MIX(f.size.width); MIX(f.size.height); MIX(orient);
#undef MIX
	if (busy || h != drawnHash || !drawnOnce) { drawnHash = h; drawnOnce = YES; [self setNeedsDisplay: YES]; }
}
- (void)drawRect:(NSRect)r
{
	CGContextRef c = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	if (getenv("DOCK_LOG")) { static int k; if (k++ < 3) NSLog(@"dock: drawRect %@ port %p", NSStringFromRect(r), c); }
	if (!c) return;
	if (getenv("DOCK_TEST")) { CGContextSetRGBFillColor(c, 1, 0, 0, 1); CGContextFillRect(c, CGRectMake(10, 10, 200, 100)); NSRectFill(NSMakeRect(250, 10, 100, 100)); }
	else { CGContextSaveGState(c); CGContextClearRect(c, NSRectToCGRect([self bounds])); CGContextRestoreGState(c); }
	DockScene sc = { m, items, tiles, n, slots, bar, [self originX], [self bounds].size.height, hover, fanOpen ? &fan : NULL, orient, [self bounds].size.width, (gGrid && [gGrid isVisible]) ? gGridTile + 1 : 0 };
	DockRender(c, &sc);
	if (ctxOpen) [self drawContext];
	if ([self poofing]) [self drawPoof];
}
- (int)tileAt:(double)x
{
	for (int i = 0; i < n; i++) if (!DOCK_IS_GAP(items[i].kind) && x >= slots[i].x && x < slots[i].x + slots[i].w) return i;
	return -1;
}
- (double)screenX:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; return (orient ? [self bounds].size.height - p.y : p.x) + [self originX]; }
- (NSArray *)sortedNamesOf:(int)i       /* the visible names of a folder tile in the order of its "Sort by" (as the fan) */
{
	NSString *dir = paths[i]; NSFileManager *fm = [NSFileManager defaultManager]; NSMutableArray *vis = [NSMutableArray array]; for (NSString *nm in [fm contentsOfDirectoryAtPath: dir error: NULL]) if (![nm hasPrefix: @"."]) [vis addObject: nm];
	int arrange = 2; if (srcKind[i] == 2) arrange = [others[srcIdx[i]][@"tile-data"][@"arrangement"] intValue];
	[vis sortUsingComparator: ^NSComparisonResult(NSString *a, NSString *b) { if (arrange == 1) return [a localizedCaseInsensitiveCompare: b]; if (arrange == 5) { NSComparisonResult r = [[a pathExtension] caseInsensitiveCompare: [b pathExtension]]; return r ?: [a localizedCaseInsensitiveCompare: b]; }
		NSString *key = arrange == 4 ? NSFileCreationDate : NSFileModificationDate; NSDate *da = [fm attributesOfItemAtPath: [dir stringByAppendingPathComponent: a] error: NULL][key], *db = [fm attributesOfItemAtPath: [dir stringByAppendingPathComponent: b] error: NULL][key]; return [db compare: da ?: [NSDate distantPast]]; }];
	return vis;
}
- (void)closeAllMenus { ctxOpen = 0; }
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
	NSString *base = [[path lastPathComponent] stringByDeletingPathExtension], *exe = [[path stringByAppendingPathComponent: @"Contents/MacOS"] stringByAppendingPathComponent: base];
	if (![[NSFileManager defaultManager] isExecutableFileAtPath: exe]) exe = [path stringByAppendingPathComponent: base];
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
		if (d >= 0 && d < n && [self pointerAbove] > 40 && srcKind[d] != -1) {
			int px, py; if (wsc && ws_cursor_position(wsc, &px, &py) == 0) { poofAt = NSMakePoint(px, screenH - py); poofT0 = Now(); }
			[self keepToggle: d remove: YES];
		}       /* dragged out of the Dock: it is removed */
		else { [self savePrefs]; [self reload]; }
		return;
	}
	if (fanOpen || i < 0 || i >= n || !tiles[i].label) return;
	NSString *path = paths[i];
	if ([path hasSuffix: @"/Apps.app"]) { [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.apps.toggle" object: nil userInfo: nil deliverImmediately: YES]; return; }
	if (items[i].kind == DOCK_APP) { for (int k = nmini - 1; k >= 0; k--) if (mini[k].appItem == i && mini[k].phase == 2) { [self restoreMini: k]; return; } }
	if (items[i].kind == DOCK_MINIMIZED) { for (int k = 0; k < nmini; k++) if (mini[k].item == i) [self restoreMini: k]; return; }
	if (items[i].kind == DOCK_OTHER) { if ([self isDirTile: i]) { int showas = srcKind[i] == 2 ? [others[srcIdx[i]][@"tile-data"][@"showas"] intValue] : 1; NSArray *sorted = [self sortedNamesOf: i]; if (showas == 3) { NSString *dir = path; double top = bar.bottom_margin + bar.bar_h + 8; DockListMenu *lm = [[DockListMenu alloc] init]; lm->dir = dir; lm->names = sorted; lm->maxRows = (int)floor(([[NSScreen mainScreen] frame].size.height - top - 110) / 24); lm->open = ^(NSString *p) { [self openPath: p]; }; lm->command = ^(int code) { self->ctxItem = i; NSMenuItem *mi = [[NSMenuItem alloc] init]; [mi setTag: code]; [self ctx: mi]; }; NSMenu *nm = [lm menu]; objc_setAssociatedObject(self, "dlm", lm, OBJC_ASSOCIATION_RETAIN); NSPoint cp = NSMakePoint(slots[i].cx, top); [[DockMenuFit alloc] initFor: nm at: cp]; NSEvent *ev = [NSEvent mouseEventWithType: NSRightMouseDown location: [self convertPoint: cp toView: nil] modifierFlags: 0 timestamp: [[NSProcessInfo processInfo] systemUptime] windowNumber: [[self window] windowNumber] context: nil eventNumber: 0 clickCount: 1 pressure: 1]; [NSMenu popUpContextMenu: nm withEvent: ev forView: self]; return; } if (showas == 2 || (showas == 0 && [sorted count] > 16)) { NSString *dir = path, *tt = tiles[i].label ? @(tiles[i].label) : @""; double top = bar.bottom_margin + bar.bar_h; [self closeAllMenus]; gGridTile = i; ShowDockGrid(tt, dir, sorted, slots[i].cx, top, ^(NSString *nm) { [self openPath: [dir stringByAppendingPathComponent: nm]]; }); } else [self openFan: i]; } else [self openPath: path]; return; }
	if (items[i].kind == DOCK_TRASH) { return; }
	if (items[i].kind == DOCK_APP && [self pidOfApp: path] > 0) { if (![self activateApp: path]) [[NSDistributedNotificationCenter defaultCenter] postNotificationName: @"com.wsbsd.dock.reopen" object: nil userInfo: @{ @"path": path, @"pid": @([self pidOfApp: path]) } deliverImmediately: YES]; return; }        /* a running application comes to the front instead of starting again; one without a window of its own is asked to open one (applicationShouldHandleReopen:, as on the Mac) */
	[self launchItem: i];
}
/* brings the windows of a running application to the front, in their order; NO when it has none on the screen */
- (BOOL)activateApp:(NSString *)bundle
{
	int pid = [self pidOfApp: bundle]; if (!pid || !wsc) return NO;
	uint32_t ids[256]; int total = 0; if (ws_win_list(wsc, 0, 1, ids, 256, &total) != 0) return NO;
	int got = 0;
	for (int k = (total < 256 ? total : 256) - 1; k >= 0; k--) {                          /* back to front: the frontmost ends up on top */
		ws_win w = { .id = ids[k], .px = NULL }; int lv = 0, owner = 0, rights = 0; long wpid = 0;
		if (getenv("DOCK_LOG")) { ws_win_get_level(wsc, &w, &lv); ws_win_get_owner(wsc, &w, &owner, &rights); ws_conn_pid_version(wsc, owner, &wpid); NSLog(@"dock: activate %d: window %u level %d owner %d pid %ld", pid, ids[k], lv, owner, wpid); wpid = 0; }
		if (ws_win_get_level(wsc, &w, &lv) || lv != 0 || ws_win_get_owner(wsc, &w, &owner, &rights) || ws_conn_pid_version(wsc, owner, &wpid) || wpid != pid) continue;
		ws_win_order(wsc, &w, WS_ABOVE, 0); got++;
	}
	return got > 0;
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
	case 2: { int pid = [self pidOfApp: paths[i]]; if (pid > 0) kill(pid, SIGTERM); } break;           /* Quit */
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
static NSFont *MenuFont(void) { return [NSFont systemFontOfSize: 13]; }
static NSDictionary *kMenuAttrs(BOOL dis, BOOL sel) { return @{ NSFontAttributeName: MenuFont(), NSForegroundColorAttributeName: sel ? [NSColor whiteColor] : [NSColor colorWithCalibratedWhite: 1 alpha: dis ? 0.25 : 0.85] }; }
/* the metrics of the real context menu (measured on the Mac): rows 24 high, separators 11, 5 above and below, 16 on each side of the text, 14 more for a column of check marks, 31 more for a submenu's arrow; width rounded up */
static NSSize MenuSize(NSArray *its)
{
	double w = 0, h = 10; BOOL check = NO, sub = NO;
	for (NSDictionary *d in its) { if (d[@"sep"]) { h += 11; continue; } h += 24; w = fmax(w, [d[@"t"] sizeWithAttributes: @{ NSFontAttributeName: MenuFont() }].width); if ([d[@"on"] boolValue]) check = YES; if (d[@"sub"]) sub = YES; }
	return NSMakeSize(ceil(w + 32 + (check ? 14 : 0) + (sub ? 31 : 0)), h);
}
static BOOL MenuHasCheck(NSArray *its) { for (NSDictionary *d in its) if ([d[@"on"] boolValue]) return YES; return NO; }

- (void)rightMouseDown:(NSEvent *)e
{
	int i = [self tileAt: [self screenX: e]]; if (ctxOpen) { ctxOpen = 0; return; } if (i < 0 || fanOpen) return; ctxItem = i; hover = -1;
	NSString *name = tiles[i].label ? @(tiles[i].label) : @""; NSMutableArray *its = [NSMutableArray array];
	int k = items[i].kind; BOOL running = k == DOCK_APP && [self pidOfApp: paths[i]] > 0;
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
	if (getenv("DOCK_TESTMENU")) its = [@[ ESub(@"Options", @[ E(@"Keep in Dock", 4, YES, NO) ]), ESep(), E(@"Open", 1, NO, NO), E(@"Quit", 2, NO, NO) ] mutableCopy];       /* the menu of the comparison with the real Mac */
	if (getenv("DOCK_DEBUG")) NSLog(@"dock menu for tile %d (%lu items)", i, (unsigned long)[its count]);
	if (!getenv("DOCK_CUSTOM_MENU")) {
		NSMenu *nm = NativeMenu(its, self); double top = bar.bottom_margin + bar.bar_h + 8; NSPoint at = NSMakePoint(orient ? NSMidX([self bounds]) : slots[i].cx, top); (void)at; if (getenv("DOCK_DEBUG")) NSLog(@"dock menu cp %@ win %@ top %f cx %f", NSStringFromPoint([[self window] convertBaseToScreen: [self convertPoint: NSMakePoint(slots[i].cx, top) toView: nil]]), NSStringFromRect([[self window] frame]), top, slots[i].cx);
		NSPoint cp = NSMakePoint(slots[i].cx, top);       /* the tiles' x is in screen coordinates and the bar's window sits on the screen's bottom edge: view y = screen y */
		[[DockMenuFit alloc] initFor: nm at: cp];
		NSEvent *ev = [NSEvent mouseEventWithType: NSRightMouseDown location: [self convertPoint: NSMakePoint(slots[i].cx, top) toView: nil] modifierFlags: 0 timestamp: [[NSProcessInfo processInfo] systemUptime] windowNumber: [[self window] windowNumber] context: nil eventNumber: 0 clickCount: 1 pressure: 1];
		__block BOOL chose = NO; id ob = [[NSNotificationCenter defaultCenter] addObserverForName: NSMenuDidSendActionNotification object: nil queue: nil usingBlock: ^(NSNotification *n) { chose = YES; }]; NSDate *t0 = [NSDate date];
		[NSMenu popUpContextMenu: nm withEvent: ev forView: self];
		if (!chose && -[t0 timeIntervalSinceNow] < 0.5) { [[DockMenuFit alloc] initFor: nm at: cp]; [NSMenu popUpContextMenu: nm withEvent: ev forView: self]; }       /* a quick click keeps the menu open until the next click, as on the Mac */
		[[NSNotificationCenter defaultCenter] removeObserver: ob]; return;
	}
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
	for (int j = 0; j <= q; j++) { double hgt = its[j][@"sep"] ? 11 : 24; y -= hgt; if (j == q) return NSMakeRect(r.origin.x + 5, y, r.size.width - 10, hgt); }
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
	NSBezierPath *bp = [NSBezierPath bezierPathWithRoundedRect: r xRadius: 12 yRadius: 12];
	for (int i = 14; i >= 1; i--) {                                                       /* the shadow, outside the menu only (rings of falling strength: a clip would stay in force for the texts): 13 % at the edge, gone after 14 px, a little heavier below */
		double al = 0.135 * exp(-(i - 1) / 5.5); NSBezierPath *ring = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, -i + 0.5, -i + 0.5) xRadius: 12 + i yRadius: 12 + i];
		[[NSColor colorWithCalibratedWhite: 0 alpha: al] setStroke]; [ring setLineWidth: 1]; [ring stroke];
	}
	if (!ctxGlass) { [[NSColor colorWithCalibratedWhite: 0.25 alpha: 1] setFill]; [bp fill]; }     /* the material is the compositor's; this fill is the fallback */
	NSBezierPath *ol = [NSBezierPath bezierPathWithRoundedRect: NSInsetRect(r, -0.5, -0.5) xRadius: 12.5 yRadius: 12.5];   /* the 1 px dark line just outside the edge */
	[[NSColor colorWithCalibratedWhite: 0 alpha: 0.85] setStroke]; [ol setLineWidth: 1]; [ol stroke];
	BOOL check = MenuHasCheck(its); NSFont *font = MenuFont();
	for (int q = 0; q < (int)[its count]; q++) {
		NSDictionary *d = its[q]; NSRect ir = [self rectOfItem: q in: its menu: r];
		if (d[@"sep"]) { [[NSColor colorWithCalibratedWhite: 1 alpha: 0.14] setFill]; NSRectFill(NSMakeRect(r.origin.x + 16, ir.origin.y + 5, r.size.width - 31, 1)); continue; }
		BOOL dis = [d[@"dis"] boolValue], sel = q == hv && !dis;
		if (sel) { [[NSColor colorWithCalibratedRed: 0 green: 0.478 blue: 1 alpha: 1] setFill]; [[NSBezierPath bezierPathWithRoundedRect: ir xRadius: 8 yRadius: 8] fill]; }
		NSDictionary *at = kMenuAttrs(dis, sel); double base = ir.origin.y + ir.size.height - 16.5, oy = base + [font descender];            /* the baseline lies 16.5 below the row's top */
		[d[@"t"] drawAtPoint: NSMakePoint(r.origin.x + 16 + (check ? 14 : 0), oy) withAttributes: at];
		if ([d[@"on"] boolValue]) [@"\u2713" drawAtPoint: NSMakePoint(r.origin.x + 12, oy) withAttributes: at];
		if (d[@"sub"]) {                                                                                                     /* the arrow: 5 wide, 9 high, 22 from the right edge */
			double cx = r.origin.x + r.size.width - 26, cy = ir.origin.y + ir.size.height / 2;
			CGContextSaveGState(c); CGContextSetLineWidth(c, 1.6); CGContextSetLineCap(c, kCGLineCapRound); CGContextSetLineJoin(c, kCGLineJoinRound);
			CGContextSetRGBStrokeColor(c, 1, 1, 1, sel ? 1 : 0.85); CGContextMoveToPoint(c, cx, cy + 4.5); CGContextAddLineToPoint(c, cx + 4.5, cy); CGContextAddLineToPoint(c, cx, cy - 4.5); CGContextStrokePath(c); CGContextRestoreGState(c);
		}
	}
}
- (void)drawPoof                                                                /* the puff of smoke of a tile dragged out of the Dock: grey clouds that swell and thin out */
{
	CGContextRef c = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort]; double t = (Now() - poofT0) / 0.6; if (t > 1) return;
	for (int k = 0; k < 7; k++) {
		double a = k * 0.9 + 0.4, d = 26 * t * (0.4 + 0.12 * k), r = 14 + 34 * t + 4 * (k % 3), al = 0.55 * (1 - t) * (1 - t) * (k == 0 ? 1.0 : 0.8);
		CGFloat x = poofAt.x + cos(a) * d, y = poofAt.y + sin(a) * d * 0.8 + 10 * t;
		for (int q = 0; q < 6; q++) { double rr = r * (1.0 - q / 6.0); CGContextSetRGBFillColor(c, 0.85, 0.85, 0.87, al / 4); CGContextFillEllipseInRect(c, CGRectMake(x - rr, y - rr, 2 * rr, 2 * rr)); }                      /* a soft edge: nested discs */
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
