/* The appearance and the accent colour of the desktop, kept where the Mac keeps them: NSGlobalDomain, keys AppleInterfaceStyle ("Dark" or absent) and AppleAccentColor (absent = blue,
 * 0 red, 1 orange, 2 yellow, 3 green, 5 purple, 6 pink, -1 graphite). WSD_APPEARANCE=light|dark still wins (the tests use it). Where the Mac has no key (a fresh image) the desktop is dark, the
 * look this system was measured in. The programs re-read the keys every second and, when one changed, post AppleInterfaceThemeChangedNotification and NSSystemColorsDidChangeNotification (the Mac
 * sends the first one through the distributed centre) and redraw their windows. */
#import <AppKit/AppKit.h>
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

static void Redraw(NSView *v) { [v setNeedsDisplay: YES]; for (NSView *s in [v subviews]) Redraw(s); }
@interface WsdAppearanceWatch : NSObject { BOOL dark; int accent; } @end
@implementation WsdAppearanceWatch
- (instancetype)init { if ((self = [super init])) { dark = WsdAppearanceIsDark(); accent = WsdAccentIndex(); } return self; }
- (void)tick:(NSTimer *)t
{
	BOOL d = WsdAppearanceIsDark(); int a = WsdAccentIndex(); if (getenv("WSD_DEBUG")) NSLog(@"wsd-back: appearance tick dark %d accent %d (was %d %d)", d, a, dark, accent); if (d == dark && a == accent) return; dark = d; accent = a;
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
