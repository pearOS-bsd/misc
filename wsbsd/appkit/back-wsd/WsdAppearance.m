/* The appearance and the accent colour of the desktop, kept where the Mac keeps them: NSGlobalDomain, keys AppleInterfaceStyle ("Dark" or absent) and AppleAccentColor (absent = blue,
 * 0 red, 1 orange, 2 yellow, 3 green, 5 purple, 6 pink, -1 graphite). WSD_APPEARANCE=light|dark still wins (the tests use it). Where the Mac has no key (a fresh image) the desktop is dark, the
 * look this system was measured in. The programs re-read the keys every second and, when one changed, post AppleInterfaceThemeChangedNotification and NSSystemColorsDidChangeNotification (the Mac
 * sends the first one through the distributed centre) and redraw their windows. */
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#include <sys/stat.h>
#include <time.h>

/* the global preferences: the Mac's own file first (~/Library/Preferences/.GlobalPreferences.plist), then the NSGlobalDomain file GNUstep's defaults tool writes, then the program's defaults */
static id GlobalValue(NSString *key)
{
	static NSMutableDictionary *cache, *memo; static time_t at; if (!cache) { cache = [[NSMutableDictionary alloc] init]; memo = [[NSMutableDictionary alloc] init]; }
	time_t now = time(NULL); if (now != at) { [memo removeAllObjects]; at = now; } id hit = memo[key]; if (hit) return hit == [NSNull null] ? nil : hit; id found = nil;
	for (NSString *f in @[ [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Preferences/.GlobalPreferences.plist"], [NSHomeDirectory() stringByAppendingPathComponent: @"GNUstep/Defaults/NSGlobalDomain.plist"] ]) {
		struct stat sb; if (stat([f fileSystemRepresentation], &sb)) continue; NSNumber *m = [NSNumber numberWithLongLong: (long long)sb.st_mtime * 1000000000LL + sb.st_mtim.tv_nsec]; NSDictionary *c = cache[f];
		if (!c || ![c[@"m"] isEqual: m]) { NSData *d = [NSData dataWithContentsOfFile: f]; id pl = d ? [NSPropertyListSerialization propertyListWithData: d options: 0 format: NULL error: NULL] : nil; c = @{ @"m": m, @"d": [pl isKindOfClass: [NSDictionary class]] ? pl : @{} }; cache[f] = c; }
		if (c[@"d"][key]) { found = c[@"d"][key]; break; }
	}
	found = found ?: [[NSUserDefaults standardUserDefaults] objectForKey: key]; memo[key] = found ?: [NSNull null]; return found;
}
static NSString *StyleKey(void) { id v = GlobalValue(@"AppleInterfaceStyle"); return [v isKindOfClass: [NSString class]] ? v : nil; }
BOOL WsdAppearanceIsDark(void)
{
	const char *e = getenv("WSD_APPEARANCE"); if (e) return strcmp(e, "light") != 0;
	NSString *s = StyleKey(); if (!s) return YES; return [s caseInsensitiveCompare: @"Dark"] == NSOrderedSame;
}
int WsdAccentIndex(void)
{
	id v = GlobalValue(@"AppleAccentColor"); if (!v) return 4; return [v intValue];          /* 4: the default blue */
}
void WsdAccentRGB(BOOL dark, double *r, double *g, double *b)                                      /* NSColor.controlAccentColor of the Mac, sRGB, per accent and appearance */
{
	static const double t[][7] = { /* index, light rgb, dark rgb */
		{ -1, 0.5961, 0.5961, 0.6157, 0.5961, 0.5961, 0.6157 }, { 0, 1.0000, 0.2314, 0.1882, 1.0000, 0.2706, 0.2275 }, { 1, 1.0000, 0.5843, 0.0000, 1.0000, 0.6235, 0.0392 },
		{ 2, 1.0000, 0.8000, 0.0000, 1.0000, 0.8392, 0.0392 }, { 3, 0.2039, 0.7804, 0.3490, 0.1882, 0.8196, 0.3451 }, { 4, 0.0000, 0.4784, 1.0000, 0.0000, 0.4784, 1.0000 },
		{ 5, 0.6863, 0.3216, 0.8706, 0.7490, 0.3529, 0.9490 }, { 6, 1.0000, 0.1765, 0.3333, 1.0000, 0.2157, 0.3725 } };
	int ix = WsdAccentIndex(); const double *row = t[5]; for (unsigned i = 0; i < sizeof t / sizeof t[0]; i++) if ((int)t[i][0] == ix) row = t[i];
	*r = row[dark ? 4 : 1]; *g = row[dark ? 5 : 2]; *b = row[dark ? 6 : 3];
}


/* "Tint window background with wallpaper color" (System Settings > Appearance; the key is AppleReduceDesktopTinting, 1 = off). Measured on the Mac with plain titled windows put over a
 * wallpaper (a dark blue picture) at 16 places: in the dark appearance the window colour is (27,27,27) + 0.0975 * the colour of the wallpaper behind the window (16 samples, every channel within one
 * level), in the light appearance it stays white. The wallpaper behind a window is known from a coarse grid of colours the Finder writes when it draws the picture
 * (~/Library/Caches/com.wsbsd.wallpaper/grid.plist: w, h, rgb bytes, the picture scaled to fill the screen); without it nothing is tinted. */
static NSDictionary *WallpaperGrid(void)
{
	static NSDictionary *grid; static time_t checked; static long long stamp; time_t now = time(NULL); if (now == checked) return grid; checked = now;
	NSString *f = [NSHomeDirectory() stringByAppendingPathComponent: @"Library/Caches/com.wsbsd.wallpaper/grid.plist"]; struct stat sb; if (stat([f fileSystemRepresentation], &sb)) { [grid release]; grid = nil; stamp = 0; return nil; }
	long long m = (long long)sb.st_mtime * 1000000000LL + sb.st_mtim.tv_nsec; if (m == stamp && grid) return grid; stamp = m; NSDictionary *d = [NSDictionary dictionaryWithContentsOfFile: f];
	[grid release]; grid = ([d[@"w"] intValue] > 0 && [d[@"h"] intValue] > 0 && [d[@"rgb"] length] >= (NSUInteger)([d[@"w"] intValue] * [d[@"h"] intValue] * 3)) ? [d retain] : nil; return grid;      /* the library is not ARC: the cache is retained */
}
long long WsdWallpaperStamp(void) { NSDictionary *g = WallpaperGrid(); return g ? (long long)[g[@"rgb"] length] * 31 + [g[@"rgb"] hash] : 0; }
BOOL WsdWindowTintingOn(void) { id v = GlobalValue(@"AppleReduceDesktopTinting"); return WsdAppearanceIsDark() && !(v && [v boolValue]) && WallpaperGrid() != nil; }
/* the tinted colour of a window at frame (screen coordinates, origin bottom left, screenHeight of the screen); NO when there is no tint */
BOOL WsdWindowTint(NSRect frame, double screenWidth, double screenHeight, int *r, int *g, int *b)
{
	if (!WsdWindowTintingOn() || getenv("WSD_WINDOW_BG") || screenWidth < 1 || screenHeight < 1) return NO; NSDictionary *gr = WallpaperGrid(); int gw = [gr[@"w"] intValue], gh = [gr[@"h"] intValue]; const unsigned char *px = [gr[@"rgb"] bytes];
	int x0 = MAX(0, (int)floor(frame.origin.x / screenWidth * gw)), x1 = MIN(gw, MAX(x0 + 1, (int)ceil(NSMaxX(frame) / screenWidth * gw)));
	double top = screenHeight - NSMaxY(frame), bot = screenHeight - frame.origin.y; int y0 = MAX(0, (int)floor(top / screenHeight * gh)), y1 = MIN(gh, MAX(y0 + 1, (int)ceil(bot / screenHeight * gh)));
	if (x0 >= gw) x0 = gw - 1; if (y0 >= gh) y0 = gh - 1; if (x1 <= x0) x1 = x0 + 1; if (y1 <= y0) y1 = y0 + 1; double sum[3] = { 0, 0, 0 }; int n = 0;
	for (int y = y0; y < y1; y++) for (int x = x0; x < x1; x++) { const unsigned char *q = px + (y * gw + x) * 3; sum[0] += q[0]; sum[1] += q[1]; sum[2] += q[2]; n++; }
	if (!n) return NO; *r = (int)(27 + 0.0975 * sum[0] / n + 0.5); *g = (int)(27 + 0.0975 * sum[1] / n + 0.5); *b = (int)(27 + 0.0975 * sum[2] / n + 0.5); return YES;
}
/* the tinted background of a window that keeps the default one (the system window colour), nil when it has its own colour or there is no tint */
NSColor *WsdTintedWindowBackground(NSWindow *w)
{
	if (!w || !WsdWindowTintingOn()) return nil; NSColor *own = [w backgroundColor], *sys = [NSColor windowBackgroundColor];
	NSColor *a = [own colorUsingColorSpaceName: NSCalibratedRGBColorSpace], *b = [sys colorUsingColorSpaceName: NSCalibratedRGBColorSpace]; if (!a || !b) return nil;
	if (fabs([a redComponent] - [b redComponent]) > 0.003 || fabs([a greenComponent] - [b greenComponent]) > 0.003 || fabs([a blueComponent] - [b blueComponent]) > 0.003 || [a alphaComponent] < 0.99) return nil;      /* an app's own colour stays */
	NSScreen *sc = [NSScreen mainScreen]; if (!sc) return nil; int r, g, bl; if (!WsdWindowTint([w frame], [sc frame].size.width, [sc frame].size.height, &r, &g, &bl)) return nil;
	return [NSColor colorWithCalibratedRed: r / 255.0 green: g / 255.0 blue: bl / 255.0 alpha: 1];
}

static void Redraw(NSView *v) { [v setNeedsDisplay: YES]; for (NSView *s in [v subviews]) Redraw(s); }
@interface WsdAppearanceWatch : NSObject { BOOL dark; int accent; long long wall; BOOL reduce; } @end
@implementation WsdAppearanceWatch
- (instancetype)init { if ((self = [super init])) { dark = WsdAppearanceIsDark(); accent = WsdAccentIndex(); wall = WsdWallpaperStamp(); reduce = [GlobalValue(@"AppleReduceDesktopTinting") boolValue]; } return self; }
- (void)tick:(NSTimer *)t
{
	BOOL d = WsdAppearanceIsDark(); int a = WsdAccentIndex(); if (getenv("WSD_DEBUG")) NSLog(@"wsd-back: appearance tick dark %d accent %d (was %d %d)", d, a, dark, accent); long long wl = WsdWallpaperStamp(); BOOL rd = [GlobalValue(@"AppleReduceDesktopTinting") boolValue]; BOOL tint = (wl != wall || rd != reduce); wall = wl; reduce = rd; if (d == dark && a == accent && !tint) return; dark = d; accent = a;
	[[NSNotificationCenter defaultCenter] postNotificationName: @"AppleInterfaceThemeChangedNotification" object: nil];
	[[NSNotificationCenter defaultCenter] postNotificationName: NSSystemColorsDidChangeNotification object: nil];
	for (NSWindow *w in [NSApp windows]) { Redraw([[w contentView] superview] ?: [w contentView]); [w display]; }
}
@end
void WsdInstallAppearanceWatch(void)
{
	static WsdAppearanceWatch *w; if (w) return; w = [WsdAppearanceWatch new];
	NSTimer *t = [NSTimer scheduledTimerWithTimeInterval: 1.0 target: w selector: @selector(tick:) userInfo: nil repeats: YES]; [[NSRunLoop currentRunLoop] addTimer: t forMode: NSEventTrackingRunLoopMode]; [[NSRunLoop currentRunLoop] addTimer: t forMode: NSModalPanelRunLoopMode];
}
