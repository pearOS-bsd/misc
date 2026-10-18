/* Dock.app for wsbsd: the Dock of the desktop. A borderless window at the bottom of the screen draws the bar with DockRender; the layout (with magnification) comes from dock_layout.c, the genie from genie.c.
 * The items are the persistent applications of ~/Library/Preferences/com.apple.dock.plist (or a default set), the running ones get a dot. */
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#include <unistd.h>
#include <signal.h>
#include "DockRender.h"

#define MAXITEMS 64
static double Now(void) { return CACurrentMediaTime(); }

@interface DockView : NSView {
@public
	DockMetrics m; DockItem items[MAXITEMS]; DockTile tiles[MAXITEMS]; DockSlot slots[MAXITEMS]; DockBar bar; int n;
	NSMutableArray *paths; NSMutableArray *names; NSMutableArray *pids; NSMutableArray *labelStore;
	NSTrackingRectTag trackTag; double pointer; int hover; double scale[MAXITEMS]; double bounceStart[MAXITEMS]; NSTimer *timer; double screenW;
}
- (void)reload;
@end

@implementation DockView
- (BOOL)isFlipped { return NO; }
- (BOOL)acceptsFirstMouse:(NSEvent *)e { return YES; }
- (instancetype)initWithFrame:(NSRect)f
{
	if (!(self = [super initWithFrame: f])) return nil;
	screenW = [[NSScreen mainScreen] frame].size.width;
	m = (DockMetrics){ 58, 99, 1, (int)screenW };
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile: [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/com.apple.dock.plist"]];
	if ([prefs[@"tilesize"] intValue] > 0) m.tilesize = [prefs[@"tilesize"] intValue];
	if ([prefs[@"largesize"] intValue] > 0) m.largesize = [prefs[@"largesize"] intValue];
	if (prefs[@"magnification"]) m.magnification = [prefs[@"magnification"] boolValue];
	pointer = -1; hover = -1;
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
	items[n].kind = DOCK_TRASH; tiles[n] = (DockTile){ "Trash", "trash", 0, 0, 0 }; [paths addObject: @""]; [pids addObject: @0]; n++;
	for (int i = 0; i < n; i++) { scale[i] = 1; bounceStart[i] = 0; }
}
- (void)relayout
{
	double px = pointer;
	dock_layout(&m, items, n, px, slots, &bar);
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
	[self relayout];
	NSWindow *w = [self window];
	NSRect f = NSMakeRect(floor(bar.bar_x), 0, ceil(bar.bar_w), 170);
	NSRect cur = [w frame];
	if (fabs(f.origin.x - cur.origin.x) >= 1 || fabs(f.size.width - cur.size.width) >= 1) { [w setFrame: f display: NO]; }
	[self setNeedsDisplay: YES];
}
- (void)drawRect:(NSRect)r
{
	CGContextRef c = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
	if (getenv("DOCK_LOG")) { static int k; if (k++ < 3) NSLog(@"dock: drawRect %@ port %p", NSStringFromRect(r), c); }
	if (!c) return;
	if (getenv("DOCK_TEST")) { CGContextSetRGBFillColor(c, 1, 0, 0, 1); CGContextFillRect(c, CGRectMake(10, 10, 200, 100)); NSRectFill(NSMakeRect(250, 10, 100, 100)); }
	else { CGContextSaveGState(c); CGContextClearRect(c, NSRectToCGRect([self bounds])); CGContextRestoreGState(c); }
	DockScene sc = { m, items, tiles, n, slots, bar, floor(bar.bar_x), [self bounds].size.height, hover };
	DockRender(c, &sc);
}
- (int)tileAt:(double)x
{
	for (int i = 0; i < n; i++) if (items[i].kind != DOCK_SEPARATOR && x >= slots[i].x && x < slots[i].x + slots[i].w) return i;
	return -1;
}
- (double)screenX:(NSEvent *)e { NSPoint p = [self convertPoint: [e locationInWindow] fromView: nil]; return p.x + floor(bar.bar_x); }
- (void)mouseMoved:(NSEvent *)e { pointer = [self screenX: e]; hover = [self tileAt: pointer]; }
- (void)mouseExited:(NSEvent *)e { pointer = -1; hover = -1; }
- (void)mouseEntered:(NSEvent *)e { pointer = [self screenX: e]; }
- (void)mouseDown:(NSEvent *)e
{
	int i = [self tileAt: [self screenX: e]]; if (i < 0 || !tiles[i].label) return;
	NSString *path = paths[i];
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
		NSWindow *w = [[NSWindow alloc] initWithContentRect: NSMakeRect(v->bar.bar_x, 0, v->bar.bar_w, 170) styleMask: NSBorderlessWindowMask backing: NSBackingStoreBuffered defer: NO];
		if (getenv("DOCK_TEST")) { [w setBackgroundColor: [NSColor greenColor]]; } else { [w setOpaque: NO]; [w setBackgroundColor: [NSColor clearColor]]; } [w setHasShadow: NO]; [w setLevel: getenv("DOCK_LEVEL") ? atoi(getenv("DOCK_LEVEL")) : 20]; [w setHidesOnDeactivate: NO]; [w setCanHide: NO]; [w setContentView: v]; [w setAcceptsMouseMovedEvents: YES];
		[w orderFrontRegardless];
		[app run];
	}
	return 0;
}
